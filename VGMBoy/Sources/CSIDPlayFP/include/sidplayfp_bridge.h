#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* vgmboy_sid_handle_t;

typedef struct {
  char* title;
  char* artist;
  char* comment;
  char* system;
} vgmboy_sid_metadata_t;

vgmboy_sid_handle_t vgmboy_sid_open(const char* path, int32_t sample_rate, char** error_message);
void vgmboy_sid_close(vgmboy_sid_handle_t handle);
int32_t vgmboy_sid_read_metadata(vgmboy_sid_handle_t handle, vgmboy_sid_metadata_t* metadata, char** error_message);
int32_t vgmboy_sid_render_s16(vgmboy_sid_handle_t handle, int32_t requested_frames, int16_t* samples, int32_t* rendered_frames, char** error_message);
int32_t vgmboy_sid_seek_milliseconds(vgmboy_sid_handle_t handle, int32_t milliseconds, char** error_message);
int64_t vgmboy_sid_played_frames(vgmboy_sid_handle_t handle);
void vgmboy_sid_metadata_clear(vgmboy_sid_metadata_t* metadata);
void vgmboy_sid_free_string(char* string);

#ifdef __cplusplus
}
#endif
