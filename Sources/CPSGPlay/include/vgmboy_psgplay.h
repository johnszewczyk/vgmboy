// SPDX-License-Identifier: GPL-2.0

#ifndef VGMBOY_PSGPLAY_H
#define VGMBOY_PSGPLAY_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *vgmboy_psgplay_handle_t;

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
    char **error_message);

vgmboy_psgplay_handle_t vgmboy_psgplay_open(
    const char *path,
    int32_t track,
    int32_t sample_rate,
    char **error_message);

void vgmboy_psgplay_close(vgmboy_psgplay_handle_t handle);
int32_t vgmboy_psgplay_restart(vgmboy_psgplay_handle_t handle, char **error_message);
int32_t vgmboy_psgplay_select_track(vgmboy_psgplay_handle_t handle, int32_t track, char **error_message);
int32_t vgmboy_psgplay_configure(vgmboy_psgplay_handle_t handle, int32_t play_ms, char **error_message);
int32_t vgmboy_psgplay_seek(vgmboy_psgplay_handle_t handle, int32_t milliseconds, char **error_message);
int32_t vgmboy_psgplay_read_s16(
    vgmboy_psgplay_handle_t handle,
    int32_t requested_frames,
    int16_t *samples,
    int32_t *rendered_frames,
    char **error_message);
int32_t vgmboy_psgplay_track_ended(vgmboy_psgplay_handle_t handle);
int64_t vgmboy_psgplay_played_frames(vgmboy_psgplay_handle_t handle);
void vgmboy_psgplay_error_message_free(char *error_message);

#ifdef __cplusplus
}
#endif

#endif
