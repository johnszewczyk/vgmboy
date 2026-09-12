#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *mdx_player_handle_t;

typedef struct {
    char *title;
    char *pdx_name;
    char *system;
    int32_t play_length_ms;
    int32_t channel_count;
    int32_t has_pdx;
} mdx_metadata_t;

mdx_player_handle_t mdx_player_create(const char *path, int32_t sample_rate, char **error_message);
void mdx_player_destroy(mdx_player_handle_t handle);
int32_t mdx_player_read_metadata(mdx_player_handle_t handle, mdx_metadata_t *metadata, char **error_message);
int32_t mdx_player_render_s16(mdx_player_handle_t handle, int32_t requested_frames, int16_t *samples, int32_t *rendered_frames, char **error_message);
int32_t mdx_player_seek_milliseconds(mdx_player_handle_t handle, int32_t milliseconds, char **error_message);
int32_t mdx_player_track_ended(mdx_player_handle_t handle);
int64_t mdx_player_played_frames(mdx_player_handle_t handle);
void mdx_metadata_clear(mdx_metadata_t *metadata);
void mdx_error_message_free(char *error_message);

#ifdef __cplusplus
}
#endif
