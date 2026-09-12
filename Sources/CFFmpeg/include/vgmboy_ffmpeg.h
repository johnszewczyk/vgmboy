#ifndef VGMBoy_FFMPEG_H
#define VGMBoy_FFMPEG_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vgmboy_ffmpeg_decoder vgmboy_ffmpeg_decoder;

vgmboy_ffmpeg_decoder *vgmboy_ffmpeg_decoder_create(const char *path, int output_rate, char **error_message);
void vgmboy_ffmpeg_decoder_destroy(vgmboy_ffmpeg_decoder *decoder);
int vgmboy_ffmpeg_decoder_start(vgmboy_ffmpeg_decoder *decoder, char **error_message);
int vgmboy_ffmpeg_decoder_seek(vgmboy_ffmpeg_decoder *decoder, int64_t milliseconds, char **error_message);
int vgmboy_ffmpeg_decoder_read(vgmboy_ffmpeg_decoder *decoder, float *left, float *right, int frames, int *frames_read, char **error_message);
int64_t vgmboy_ffmpeg_decoder_duration_ms(const vgmboy_ffmpeg_decoder *decoder);
const char *vgmboy_ffmpeg_decoder_title(const vgmboy_ffmpeg_decoder *decoder);
const char *vgmboy_ffmpeg_decoder_album(const vgmboy_ffmpeg_decoder *decoder);
const char *vgmboy_ffmpeg_decoder_artist(const vgmboy_ffmpeg_decoder *decoder);
const char *vgmboy_ffmpeg_decoder_comment(const vgmboy_ffmpeg_decoder *decoder);
void vgmboy_ffmpeg_error_message_free(char *message);

#ifdef __cplusplus
}
#endif

#endif
