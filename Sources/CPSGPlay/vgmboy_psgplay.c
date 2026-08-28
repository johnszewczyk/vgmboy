// SPDX-License-Identifier: GPL-2.0

#include "vgmboy_psgplay.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ice/ice.h"
#include "psgplay/psgplay.h"
#include "psgplay/sndh.h"
#include "psgplay/stereo.h"

#define VGMBOY_PSGPLAY_MAX_INPUT_SIZE (256u * 1024u * 1024u)
#define VGMBOY_PSGPLAY_TEXT_SIZE 1024

struct vgmboy_psgplay {
    unsigned char *data;
    size_t size;
    struct psgplay *player;
    int32_t track;
    int32_t track_count;
    int32_t sample_rate;
    int32_t stop_ms;
    int64_t played_frames;
    int ended;
};

static char *copy_message(const char *message)
{
    const size_t length = strlen(message);
    char *copy = malloc(length + 1);
    if (copy == NULL)
        return NULL;
    memcpy(copy, message, length + 1);
    return copy;
}

static void set_error(char **error_message, const char *message)
{
    if (error_message != NULL)
        *error_message = copy_message(message);
}

static void clear_error(char **error_message)
{
    if (error_message != NULL)
        *error_message = NULL;
}

static int normalize_data(
    const void *input,
    size_t input_size,
    const void **output,
    size_t *output_size,
    unsigned char **owned,
    char **error_message)
{
    clear_error(error_message);
    *output = input;
    *output_size = input_size;
    *owned = NULL;

    if (input == NULL || input_size == 0 || input_size > VGMBOY_PSGPLAY_MAX_INPUT_SIZE) {
        set_error(error_message, "SNDH input is empty or exceeds the safety limit.");
        return 0;
    }

    if (input_size >= ICE_HEADER_SIZE && ice_identify(input, input_size)) {
        const size_t expanded_size = ice_decrunched_size(input, input_size);
        if (expanded_size == 0 || expanded_size > VGMBOY_PSGPLAY_MAX_INPUT_SIZE) {
            set_error(error_message, "ICE-compressed SNDH has an invalid decompressed size.");
            return 0;
        }
        unsigned char *expanded = malloc(expanded_size);
        if (expanded == NULL) {
            set_error(error_message, "Could not allocate memory for the decompressed SNDH.");
            return 0;
        }
        const ssize_t actual_size = ice_decrunch(expanded, input, input_size);
        if (actual_size < 0 || (size_t)actual_size != expanded_size) {
            free(expanded);
            set_error(error_message, "Could not decompress the ICE-packed SNDH.");
            return 0;
        }
        *output = expanded;
        *output_size = (size_t)actual_size;
        *owned = expanded;
    }

    if (!sndh_identify(*output, *output_size)) {
        free(*owned);
        *owned = NULL;
        set_error(error_message, "The file is not a valid uncompressed or ICE-packed SNDH.");
        return 0;
    }
    return 1;
}

static void copy_text(char *destination, size_t length, const char *source)
{
    if (destination == NULL || length == 0)
        return;
    if (source == NULL)
        source = "";
    strncpy(destination, source, length - 1);
    destination[length - 1] = '\0';
}

static int metadata_from_data(
    const void *data,
    size_t size,
    int32_t track,
    char *title,
    size_t title_length,
    char *composer,
    size_t composer_length,
    char *year,
    size_t year_length,
    char *subtune_name,
    size_t subtune_name_length,
    int32_t *track_count,
    int32_t *default_track,
    int32_t *duration_ms,
    char **error_message)
{
    int count = 1;
    int default_subtune = 1;
    float duration = 0;
    if (sndh_tag_subtune_count(&count, data, size) && (count <= 0 || count > 10000)) {
        set_error(error_message, "SNDH contains an unsafe subtune count.");
        return 0;
    }
    if (sndh_tag_default_subtune(&default_subtune, data, size) &&
        (default_subtune <= 0 || default_subtune > count))
        default_subtune = 1;
    if (track <= 0 || track > count) {
        set_error(error_message, "SNDH subtune is outside the file's declared range.");
        return 0;
    }

    if (title != NULL && title_length > 0)
        title[0] = '\0';
    if (composer != NULL && composer_length > 0)
        composer[0] = '\0';
    if (year != NULL && year_length > 0)
        year[0] = '\0';
    if (subtune_name != NULL && subtune_name_length > 0)
        subtune_name[0] = '\0';

    char buffer[VGMBOY_PSGPLAY_TEXT_SIZE];
    if (sndh_tag_title(buffer, sizeof(buffer), data, size))
        copy_text(title, title_length, buffer);
    if (sndh_tag_composer(buffer, sizeof(buffer), data, size))
        copy_text(composer, composer_length, buffer);
    if (sndh_tag_year(buffer, sizeof(buffer), data, size))
        copy_text(year, year_length, buffer);
    if (sndh_tag_subtune_name(buffer, sizeof(buffer), track, data, size))
        copy_text(subtune_name, subtune_name_length, buffer);
    if (sndh_tag_subtune_time(&duration, track, data, size) && duration > 0 && duration < 2147483.0f)
        *duration_ms = (int32_t)(duration * 1000.0f + 0.5f);
    else
        *duration_ms = 0;
    *track_count = count;
    *default_track = default_subtune;
    return 1;
}

int32_t vgmboy_psgplay_read_metadata(
    const void *data,
    size_t size,
    int32_t track,
    char *title,
    size_t title_length,
    char *composer,
    size_t composer_length,
    char *year,
    size_t year_length,
    char *subtune_name,
    size_t subtune_name_length,
    int32_t *track_count,
    int32_t *default_track,
    int32_t *duration_ms,
    char **error_message)
{
    if (track_count == NULL || default_track == NULL || duration_ms == NULL) {
        set_error(error_message, "SNDH metadata output is invalid.");
        return 1;
    }
    const void *normalized = NULL;
    size_t normalized_size = 0;
    unsigned char *owned = NULL;
    if (!normalize_data(data, size, &normalized, &normalized_size, &owned, error_message))
        return 1;
    const int result = metadata_from_data(
        normalized, normalized_size, track, title, title_length, composer, composer_length,
        year, year_length, subtune_name, subtune_name_length,
        track_count, default_track, duration_ms, error_message);
    free(owned);
    return result ? 0 : 1;
}

static int read_file(const char *path, unsigned char **data, size_t *size, char **error_message)
{
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        set_error(error_message, "Could not open the SNDH file.");
        return 0;
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        set_error(error_message, "Could not seek the SNDH file.");
        return 0;
    }
    const long end = ftell(file);
    if (end <= 0 || (unsigned long)end > VGMBOY_PSGPLAY_MAX_INPUT_SIZE) {
        fclose(file);
        set_error(error_message, "SNDH file size is invalid or exceeds the safety limit.");
        return 0;
    }
    rewind(file);
    unsigned char *contents = malloc((size_t)end);
    if (contents == NULL) {
        fclose(file);
        set_error(error_message, "Could not allocate memory for the SNDH file.");
        return 0;
    }
    const size_t actual = fread(contents, 1, (size_t)end, file);
    fclose(file);
    if (actual != (size_t)end) {
        free(contents);
        set_error(error_message, "Could not read the complete SNDH file.");
        return 0;
    }
    *data = contents;
    *size = actual;
    return 1;
}

static int restart_player(struct vgmboy_psgplay *handle, char **error_message)
{
    if (handle->player != NULL)
        psgplay_free(handle->player);
    handle->player = psgplay_init(handle->data, handle->size, handle->track, handle->sample_rate);
    handle->played_frames = 0;
    handle->ended = handle->player == NULL;
    if (handle->player == NULL) {
        set_error(error_message, "PSG play could not initialise the SNDH replay program.");
        return 0;
    }
    if (handle->stop_ms > 0)
        psgplay_stop_at_time(handle->player, handle->stop_ms / 1000.0f);
    return 1;
}

vgmboy_psgplay_handle_t vgmboy_psgplay_open(
    const char *path,
    int32_t track,
    int32_t sample_rate,
    char **error_message)
{
    clear_error(error_message);
    if (path == NULL || *path == '\0' || sample_rate <= 0) {
        set_error(error_message, "PSG play requires a path and a positive sample rate.");
        return NULL;
    }
    unsigned char *input = NULL;
    size_t input_size = 0;
    if (!read_file(path, &input, &input_size, error_message))
        return NULL;
    const void *normalized = NULL;
    size_t normalized_size = 0;
    unsigned char *owned = NULL;
    if (!normalize_data(input, input_size, &normalized, &normalized_size, &owned, error_message)) {
        free(input);
        return NULL;
    }

    struct vgmboy_psgplay *handle = calloc(1, sizeof(*handle));
    if (handle == NULL) {
        free(input);
        free(owned);
        set_error(error_message, "Could not allocate the PSG play handle.");
        return NULL;
    }
    handle->data = owned != NULL ? owned : malloc(normalized_size);
    if (handle->data == NULL) {
        free(input);
        free(owned);
        free(handle);
        set_error(error_message, "Could not retain the SNDH input.");
        return NULL;
    }
    if (owned == NULL)
        memcpy(handle->data, normalized, normalized_size);
    free(input);
    handle->size = normalized_size;
    int32_t count = 0;
    int32_t default_track = 0;
    int32_t duration_ms = 0;
    if (metadata_from_data(
            handle->data, handle->size, track, NULL, 0, NULL, 0, NULL, 0, NULL, 0,
            &count, &default_track, &duration_ms, error_message) == 0) {
        free(handle->data);
        free(handle);
        return NULL;
    }
    handle->track = track;
    handle->track_count = count;
    handle->sample_rate = sample_rate;
    if (!restart_player(handle, error_message)) {
        free(handle->data);
        free(handle);
        return NULL;
    }
    return handle;
}

void vgmboy_psgplay_close(vgmboy_psgplay_handle_t opaque)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL)
        return;
    psgplay_free(handle->player);
    free(handle->data);
    free(handle);
}

int32_t vgmboy_psgplay_restart(vgmboy_psgplay_handle_t opaque, char **error_message)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL) {
        set_error(error_message, "PSG play handle is invalid.");
        return 1;
    }
    return restart_player(handle, error_message) ? 0 : 1;
}

int32_t vgmboy_psgplay_select_track(vgmboy_psgplay_handle_t opaque, int32_t track, char **error_message)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL || track <= 0 || track > handle->track_count) {
        set_error(error_message, "SNDH subtune is outside the file's declared range.");
        return 1;
    }
    handle->track = track;
    return restart_player(handle, error_message) ? 0 : 1;
}

int32_t vgmboy_psgplay_configure(vgmboy_psgplay_handle_t opaque, int32_t play_ms, char **error_message)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL || play_ms < 0) {
        set_error(error_message, "PSG play timing configuration is invalid.");
        return 1;
    }
    handle->stop_ms = play_ms;
    if (handle->player == NULL) {
        set_error(error_message, "PSG play handle has no active player.");
        return 1;
    }
    if (play_ms > 0)
        psgplay_stop_at_time(handle->player, play_ms / 1000.0f);
    else
        psgplay_unstop(handle->player);
    clear_error(error_message);
    return 0;
}

int32_t vgmboy_psgplay_seek(vgmboy_psgplay_handle_t opaque, int32_t milliseconds, char **error_message)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL || milliseconds < 0) {
        set_error(error_message, "PSG play seek position is invalid.");
        return 1;
    }
    if (!restart_player(handle, error_message))
        return 1;
    int64_t remaining = (int64_t)milliseconds * handle->sample_rate / 1000;
    struct psgplay_stereo buffer[4096];
    while (remaining > 0) {
        const size_t requested = remaining > 4096 ? 4096 : (size_t)remaining;
        const ssize_t rendered = psgplay_read_stereo(handle->player, buffer, requested);
        if (rendered <= 0) {
            handle->ended = 1;
            break;
        }
        handle->played_frames += rendered;
        remaining -= rendered;
    }
    clear_error(error_message);
    return 0;
}

int32_t vgmboy_psgplay_read_s16(
    vgmboy_psgplay_handle_t opaque,
    int32_t requested_frames,
    int16_t *samples,
    int32_t *rendered_frames,
    char **error_message)
{
    struct vgmboy_psgplay *handle = opaque;
    if (handle == NULL || samples == NULL || rendered_frames == NULL || requested_frames < 0) {
        set_error(error_message, "PSG play audio request is invalid.");
        return 1;
    }
    *rendered_frames = 0;
    if (requested_frames == 0 || handle->ended) {
        clear_error(error_message);
        return 0;
    }
    const ssize_t rendered = psgplay_read_stereo(
        handle->player, (struct psgplay_stereo *)samples, (size_t)requested_frames);
    if (rendered < 0) {
        set_error(error_message, "PSG play failed while rendering SNDH audio.");
        return 1;
    }
    *rendered_frames = (int32_t)rendered;
    handle->played_frames += rendered;
    if (rendered == 0)
        handle->ended = 1;
    clear_error(error_message);
    return 0;
}

int32_t vgmboy_psgplay_track_ended(vgmboy_psgplay_handle_t opaque)
{
    struct vgmboy_psgplay *handle = opaque;
    return handle == NULL || handle->ended;
}

int64_t vgmboy_psgplay_played_frames(vgmboy_psgplay_handle_t opaque)
{
    struct vgmboy_psgplay *handle = opaque;
    return handle == NULL ? 0 : handle->played_frames;
}

void vgmboy_psgplay_error_message_free(char *error_message)
{
    free(error_message);
}
