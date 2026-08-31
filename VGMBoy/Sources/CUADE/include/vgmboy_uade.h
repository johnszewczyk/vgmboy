#ifndef VGMBOY_UADE_H
#define VGMBOY_UADE_H

#include <stddef.h>
#include <stdint.h>

typedef void *vgmboy_uade_handle_t;

vgmboy_uade_handle_t vgmboy_uade_create(
    const char *path,
    int32_t sample_rate,
    char **error_message
);

void vgmboy_uade_destroy(vgmboy_uade_handle_t handle);

int32_t vgmboy_uade_read_metadata(
    vgmboy_uade_handle_t handle,
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
);

int32_t vgmboy_uade_select_subsong(
    vgmboy_uade_handle_t handle,
    int32_t subsong,
    char **error_message
);

int32_t vgmboy_uade_seek(
    vgmboy_uade_handle_t handle,
    int32_t milliseconds,
    char **error_message
);

int32_t vgmboy_uade_read_s16(
    vgmboy_uade_handle_t handle,
    int32_t requested_frames,
    int16_t *samples,
    int32_t *rendered_frames,
    char **error_message
);

int64_t vgmboy_uade_played_frames(vgmboy_uade_handle_t handle);
int32_t vgmboy_uade_track_ended(vgmboy_uade_handle_t handle);
void vgmboy_uade_error_message_free(char *error_message);

#endif
