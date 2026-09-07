#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vgmboy_zxtune_player vgmboy_zxtune_player_t;

typedef struct vgmboy_zxtune_metadata {
    char *title;
    char *author;
    char *program;
    char *system;
    int32_t length_ms;
    int32_t loop_ms;
} vgmboy_zxtune_metadata_t;

vgmboy_zxtune_player_t *vgmboy_zxtune_player_create(const char *path,
                                                     int32_t sample_rate,
                                                     char **error_message);
void vgmboy_zxtune_player_destroy(vgmboy_zxtune_player_t *player);
int32_t vgmboy_zxtune_player_read_metadata(vgmboy_zxtune_player_t *player,
                                            vgmboy_zxtune_metadata_t *metadata,
                                            char **error_message);
void vgmboy_zxtune_metadata_clear(vgmboy_zxtune_metadata_t *metadata);
int32_t vgmboy_zxtune_player_set_looped(vgmboy_zxtune_player_t *player,
                                         int32_t enabled,
                                         char **error_message);
int32_t vgmboy_zxtune_player_seek(vgmboy_zxtune_player_t *player,
                                   int32_t milliseconds,
                                   char **error_message);
int32_t vgmboy_zxtune_player_render(vgmboy_zxtune_player_t *player,
                                     int32_t frame_count,
                                     int16_t *interleaved,
                                     int32_t *rendered_frames,
                                     char **error_message);
int32_t vgmboy_zxtune_player_track_ended(const vgmboy_zxtune_player_t *player);
int64_t vgmboy_zxtune_player_played_frames(const vgmboy_zxtune_player_t *player);
void vgmboy_zxtune_error_message_free(char *message);

#ifdef __cplusplus
}
#endif
