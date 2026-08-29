#include "mdx_bridge.h"

#include "mdxmini.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    t_mdxmini decoder;
    char *path;
    int32_t sample_rate;
    int64_t played_frames;
    int32_t track_ended;
} mdx_player_t;

static char *copy_string(const char *value) {
    if (!value || !*value) return NULL;
    size_t length = strlen(value) + 1;
    char *copy = (char *)malloc(length);
    if (copy) memcpy(copy, value, length);
    return copy;
}

static void set_error(char **error_message, const char *message) {
    if (error_message) *error_message = copy_string(message ? message : "MDX decoder failure.");
}

static int reopen(mdx_player_t *player, char **error_message) {
    memset(&player->decoder, 0, sizeof(player->decoder));
    mdx_set_rate(player->sample_rate);
    if (mdx_open(&player->decoder, player->path, NULL) != 0) {
        set_error(error_message, "mdxmini could not open the MDX file or its required PDX bank.");
        return -1;
    }
    player->played_frames = 0;
    player->track_ended = 0;
    return 0;
}

mdx_player_handle_t mdx_player_create(const char *path, int32_t sample_rate, char **error_message) {
    if (!path || !*path || sample_rate <= 0) {
        set_error(error_message, "MDX playback requires a file path and positive sample rate.");
        return NULL;
    }
    mdx_player_t *player = (mdx_player_t *)calloc(1, sizeof(*player));
    if (!player) {
        set_error(error_message, "Could not allocate MDX decoder state.");
        return NULL;
    }
    player->path = copy_string(path);
    player->sample_rate = sample_rate;
    if (!player->path || reopen(player, error_message) != 0) {
        free(player->path);
        free(player);
        return NULL;
    }
    return player;
}

void mdx_player_destroy(mdx_player_handle_t handle) {
    mdx_player_t *player = (mdx_player_t *)handle;
    if (!player) return;
    mdx_close(&player->decoder);
    free(player->path);
    free(player);
}

int32_t mdx_player_read_metadata(mdx_player_handle_t handle, mdx_metadata_t *metadata, char **error_message) {
    mdx_player_t *player = (mdx_player_t *)handle;
    if (!player || !metadata) {
        set_error(error_message, "MDX decoder is not initialized.");
        return -1;
    }
    memset(metadata, 0, sizeof(*metadata));
    char title[MDX_MAX_TITLE_LENGTH] = {0};
    mdx_get_title(&player->decoder, title);
    metadata->title = copy_string(title);
    metadata->pdx_name = copy_string(player->decoder.mdx ? player->decoder.mdx->pdx_name : NULL);
    metadata->system = copy_string("Sharp X68000");
    int length_seconds = mdx_get_length(&player->decoder);
    metadata->play_length_ms = length_seconds > 0 ? length_seconds * 1000 : 0;
    metadata->channel_count = mdx_get_tracks(&player->decoder);
    metadata->has_pdx = player->decoder.mdx && player->decoder.mdx->haspdx ? 1 : 0;
    return 0;
}

int32_t mdx_player_render_s16(mdx_player_handle_t handle, int32_t requested_frames, int16_t *samples, int32_t *rendered_frames, char **error_message) {
    mdx_player_t *player = (mdx_player_t *)handle;
    if (!player || requested_frames < 0 || (!samples && requested_frames > 0)) {
        set_error(error_message, "Invalid MDX render request.");
        return -1;
    }
    if (requested_frames == 0) {
        if (rendered_frames) *rendered_frames = 0;
        return 0;
    }
    int channels = pcm8_get_output_channels(player->decoder.songdata);
    if (channels != 1 && channels != 2) {
        set_error(error_message, "mdxmini returned an unsupported channel count.");
        return -1;
    }
    int16_t *native = samples;
    if (channels == 1) native = (int16_t *)malloc((size_t)requested_frames * sizeof(int16_t));
    if (!native) {
        set_error(error_message, "Could not allocate MDX render buffer.");
        return -1;
    }
    int has_more = mdx_calc_sample(&player->decoder, native, requested_frames);
    if (channels == 1) {
        for (int32_t index = requested_frames - 1; index >= 0; index--) {
            samples[index * 2] = native[index];
            samples[index * 2 + 1] = native[index];
        }
        free(native);
    }
    player->played_frames += requested_frames;
    player->track_ended = has_more == 0 ? 1 : 0;
    if (rendered_frames) *rendered_frames = requested_frames;
    return 0;
}

int32_t mdx_player_seek_milliseconds(mdx_player_handle_t handle, int32_t milliseconds, char **error_message) {
    mdx_player_t *player = (mdx_player_t *)handle;
    if (!player || milliseconds < 0) {
        set_error(error_message, "Invalid MDX seek request.");
        return -1;
    }
    if (reopen(player, error_message) != 0) return -1;
    int64_t frames = ((int64_t)milliseconds * player->sample_rate) / 1000;
    int16_t *discard = (int16_t *)malloc(4096 * 2 * sizeof(int16_t));
    if (!discard) { set_error(error_message, "Could not allocate MDX seek buffer."); return -1; }
    while (frames > 0) {
        int32_t chunk = frames > 4096 ? 4096 : (int32_t)frames;
        if (mdx_player_render_s16(player, chunk, discard, NULL, error_message) != 0) {
            free(discard);
            return -1;
        }
        frames -= chunk;
        if (player->track_ended) break;
    }
    free(discard);
    player->played_frames = ((int64_t)milliseconds * player->sample_rate) / 1000;
    player->track_ended = 0;
    return 0;
}

int32_t mdx_player_track_ended(mdx_player_handle_t handle) {
    mdx_player_t *player = (mdx_player_t *)handle;
    return !player || player->track_ended;
}

int64_t mdx_player_played_frames(mdx_player_handle_t handle) {
    mdx_player_t *player = (mdx_player_t *)handle;
    return player ? player->played_frames : 0;
}

void mdx_metadata_clear(mdx_metadata_t *metadata) {
    if (!metadata) return;
    free(metadata->title);
    free(metadata->pdx_name);
    free(metadata->system);
    memset(metadata, 0, sizeof(*metadata));
}

void mdx_error_message_free(char *error_message) { free(error_message); }
