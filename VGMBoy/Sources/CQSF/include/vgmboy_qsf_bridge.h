#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void* vgmboy_qsf_open(const char* path);
void vgmboy_qsf_close(void* handle);
int32_t vgmboy_qsf_read(void* handle, int16_t* interleavedStereo, int32_t frameCount);
int32_t vgmboy_qsf_seek(void* handle, int64_t frame);
int32_t vgmboy_qsf_finished(void* handle);
int64_t vgmboy_qsf_played_frames(void* handle);
int64_t vgmboy_qsf_play_length_frames(void* handle);
int64_t vgmboy_qsf_fade_length_frames(void* handle);
void vgmboy_qsf_configure(void* handle, int32_t playMilliseconds, int32_t fadeMilliseconds);
const char* vgmboy_qsf_tag(void* handle, const char* name);
const char* vgmboy_qsf_system_name(void* handle);

#ifdef __cplusplus
}
#endif
