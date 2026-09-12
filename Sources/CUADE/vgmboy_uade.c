#include "vgmboy_uade.h"

#include <uade/uade.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    struct uade_state *state;
    char *path;
    int32_t sample_rate;
    int32_t minimum_subsong;
    int32_t default_subsong;
    int32_t maximum_subsong;
    int64_t played_frames;
    int track_ended;
    char last_error[1024];
} VGMBoyUADE;

static void set_error(char **destination, const char *message) {
    if (!destination) return;
    const char *value = message && message[0] ? message : "UADE could not play the Amiga module.";
    size_t length = strlen(value);
    char *copy = malloc(length + 1);
    if (!copy) {
        *destination = NULL;
        return;
    }
    memcpy(copy, value, length + 1);
    *destination = copy;
}

static void set_last_error(VGMBoyUADE *handle, const char *message) {
    if (!handle) return;
    snprintf(handle->last_error, sizeof(handle->last_error), "%s",
             message && message[0] ? message : "UADE could not play the Amiga module.");
}

static const char *base_directory(void) {
    const char *configured = getenv("VGMBoy_UADE_BASE_DIR");
    if (configured && configured[0]) return configured;
    return "/opt/homebrew/opt/uade/share/uade";
}

static void copy_text(char *destination, size_t capacity, const char *source) {
    if (!destination || capacity == 0) return;
    snprintf(destination, capacity, "%s", source ? source : "");
}

static int refresh_info(VGMBoyUADE *handle, char **error_message) {
    const struct uade_song_info *info = uade_get_song_info(handle->state);
    if (!info) {
        set_error(error_message, "UADE returned no song information.");
        return -1;
    }
    handle->minimum_subsong = info->subsongs.min;
    handle->default_subsong = info->subsongs.def;
    handle->maximum_subsong = info->subsongs.max;
    if (handle->minimum_subsong < 0 || handle->maximum_subsong < handle->minimum_subsong
        || handle->maximum_subsong - handle->minimum_subsong > 10000) {
        set_error(error_message, "UADE returned an invalid subsong range.");
        return -1;
    }
    return 0;
}

static void drain_notifications(VGMBoyUADE *handle) {
    struct uade_notification notification;
    while (uade_read_notification(&notification, handle->state)) {
        if (notification.type == UADE_NOTIFICATION_SONG_END
            && !notification.song_end.happy
            && notification.song_end.reason) {
            set_last_error(handle, notification.song_end.reason);
        }
        uade_cleanup_notification(&notification);
    }
}

vgmboy_uade_handle_t vgmboy_uade_create(
    const char *path,
    int32_t sample_rate,
    char **error_message
) {
    if (!path || !path[0] || sample_rate <= 0) {
        set_error(error_message, "UADE requires a non-empty path and a positive sample rate.");
        return NULL;
    }

    struct uade_config *config = uade_new_config();
    if (!config) {
        set_error(error_message, "UADE could not allocate its configuration.");
        return NULL;
    }

    char frequency[32];
    snprintf(frequency, sizeof(frequency), "%d", sample_rate);
    uade_config_set_option(config, UC_BASE_DIR, base_directory());
    uade_config_set_option(config, UC_FREQUENCY, frequency);
    // UADE must be allowed to use its normal prefix-aware detection here.
    // Forcing content-only detection rejects valid modules such as
    // `np2.undersea` whose replayer is identified by the filename prefix.
    uade_config_set_option(config, UC_NO_CONTENT_DB, "1");
    uade_config_set_option(config, UC_ONE_SUBSONG, "1");

    struct uade_state *state = uade_new_state(config);
    free(config);
    if (!state) {
        set_error(error_message, "UADE could not initialise its Amiga emulation state.");
        return NULL;
    }

    VGMBoyUADE *handle = calloc(1, sizeof(*handle));
    if (!handle) {
        uade_cleanup_state(state);
        set_error(error_message, "UADE could not allocate playback state.");
        return NULL;
    }
    handle->state = state;
    handle->sample_rate = sample_rate;
    handle->path = strdup(path);
    if (!handle->path) {
        vgmboy_uade_destroy(handle);
        set_error(error_message, "UADE could not retain the module path.");
        return NULL;
    }

    const int result = uade_play(path, -1, state);
    if (result <= 0) {
        vgmboy_uade_destroy(handle);
        set_error(error_message, "UADE did not recognize this Amiga module.");
        return NULL;
    }
    if (refresh_info(handle, error_message) != 0) {
        vgmboy_uade_destroy(handle);
        return NULL;
    }
    handle->track_ended = 0;
    return handle;
}

void vgmboy_uade_destroy(vgmboy_uade_handle_t opaque_handle) {
    VGMBoyUADE *handle = opaque_handle;
    if (!handle) return;
    if (handle->state) uade_cleanup_state(handle->state);
    free(handle->path);
    free(handle);
}

int32_t vgmboy_uade_read_metadata(
    vgmboy_uade_handle_t opaque_handle,
    char *module_name,
    size_t module_name_capacity,
    char *format_name,
    size_t format_name_capacity,
    char *player_name,
    size_t player_name_capacity,
    int32_t *minimum_subsong,
    int32_t *default_subsong,
    int32_t *maximum_subsong,
    int32_t *duration_ms,
    char **error_message
) {
    VGMBoyUADE *handle = opaque_handle;
    if (!handle || !handle->state) {
        set_error(error_message, "UADE playback state is invalid.");
        return -1;
    }
    const struct uade_song_info *info = uade_get_song_info(handle->state);
    if (!info) {
        set_error(error_message, "UADE returned no song information.");
        return -1;
    }
    copy_text(module_name, module_name_capacity, info->modulename);
    copy_text(format_name, format_name_capacity, info->formatname);
    copy_text(player_name, player_name_capacity, info->playername);
    if (minimum_subsong) *minimum_subsong = info->subsongs.min;
    if (default_subsong) *default_subsong = info->subsongs.def;
    if (maximum_subsong) *maximum_subsong = info->subsongs.max;
    double duration = info->duration;
    if (duration < 0 || duration > 2147483.0) duration = 0;
    if (duration_ms) *duration_ms = (int32_t)(duration * 1000.0 + 0.5);
    return 0;
}

int32_t vgmboy_uade_select_subsong(
    vgmboy_uade_handle_t opaque_handle,
    int32_t subsong,
    char **error_message
) {
    VGMBoyUADE *handle = opaque_handle;
    if (!handle || !handle->state || !handle->path) {
        set_error(error_message, "UADE playback state is invalid.");
        return -1;
    }
    if (subsong < handle->minimum_subsong || subsong > handle->maximum_subsong) {
        set_error(error_message, "UADE subsong is outside the module's declared range.");
        return -1;
    }
    if (uade_stop(handle->state) < 0) {
        set_error(error_message, "UADE could not stop the previous subsong.");
        return -1;
    }
    const int result = uade_play(handle->path, subsong, handle->state);
    if (result <= 0) {
        set_error(error_message, "UADE could not start the requested subsong.");
        return -1;
    }
    handle->played_frames = 0;
    handle->track_ended = 0;
    if (refresh_info(handle, error_message) != 0) return -1;
    return 0;
}

int32_t vgmboy_uade_seek(
    vgmboy_uade_handle_t opaque_handle,
    int32_t milliseconds,
    char **error_message
) {
    VGMBoyUADE *handle = opaque_handle;
    if (!handle || !handle->state) {
        set_error(error_message, "UADE playback state is invalid.");
        return -1;
    }
    if (uade_seek(UADE_SEEK_SUBSONG_RELATIVE, (double)milliseconds / 1000.0, -1, handle->state) < 0) {
        set_error(error_message, "UADE could not seek within the subsong.");
        return -1;
    }
    handle->played_frames = ((int64_t)milliseconds * handle->sample_rate) / 1000;
    handle->track_ended = 0;
    return 0;
}

int32_t vgmboy_uade_read_s16(
    vgmboy_uade_handle_t opaque_handle,
    int32_t requested_frames,
    int16_t *samples,
    int32_t *rendered_frames,
    char **error_message
) {
    VGMBoyUADE *handle = opaque_handle;
    if (rendered_frames) *rendered_frames = 0;
    if (!handle || !handle->state || !samples || requested_frames < 0) {
        set_error(error_message, "UADE audio request is invalid.");
        return -1;
    }
    if (requested_frames == 0) return 0;
    ssize_t bytes = uade_read(samples, (size_t)requested_frames * UADE_BYTES_PER_FRAME, handle->state);
    drain_notifications(handle);
    if (bytes < 0) {
        set_error(error_message, handle->last_error);
        return -1;
    }
    if (bytes == 0) {
        handle->track_ended = 1;
        return 0;
    }
    ssize_t frames = bytes / UADE_BYTES_PER_FRAME;
    if (frames > requested_frames) frames = requested_frames;
    handle->played_frames += frames;
    if (rendered_frames) *rendered_frames = (int32_t)frames;
    return 0;
}

int64_t vgmboy_uade_played_frames(vgmboy_uade_handle_t opaque_handle) {
    VGMBoyUADE *handle = opaque_handle;
    return handle ? handle->played_frames : 0;
}

int32_t vgmboy_uade_track_ended(vgmboy_uade_handle_t opaque_handle) {
    VGMBoyUADE *handle = opaque_handle;
    return handle ? handle->track_ended : 1;
}

void vgmboy_uade_error_message_free(char *error_message) {
    free(error_message);
}
