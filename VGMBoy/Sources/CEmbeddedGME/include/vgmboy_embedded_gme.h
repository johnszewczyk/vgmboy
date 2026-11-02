#ifndef VGMBOY_EMBEDDED_GME_H
#define VGMBOY_EMBEDDED_GME_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct vgmboy_gme_handle vgmboy_gme_t;

typedef struct vgmboy_gme_track_timing_t {
    int length_ms;
    int intro_length_ms;
    int loop_length_ms;
    int play_length_ms;
    char system_name[64];
    char game_name[256];
    char song_name[256];
    char author_name[256];
} vgmboy_gme_track_timing_t;

const char* vgmboy_embedded_gme_open_data(
    const void* data,
    long size,
    vgmboy_gme_t** out,
    int sample_rate
);

void vgmboy_embedded_gme_delete(vgmboy_gme_t* emu);
int vgmboy_embedded_gme_track_count(const vgmboy_gme_t* emu);
const char* vgmboy_embedded_gme_start_track(vgmboy_gme_t* emu, int index);
const char* vgmboy_embedded_gme_play(vgmboy_gme_t* emu, int sample_count, short* out);
const char* vgmboy_embedded_gme_seek(vgmboy_gme_t* emu, int msec);
int vgmboy_embedded_gme_tell(const vgmboy_gme_t* emu);
int vgmboy_embedded_gme_track_ended(const vgmboy_gme_t* emu);
void vgmboy_embedded_gme_set_tempo(vgmboy_gme_t* emu, double tempo);
void vgmboy_embedded_gme_set_fade(vgmboy_gme_t* emu, int start_msec, int length_msec);
void vgmboy_embedded_gme_ignore_silence(vgmboy_gme_t* emu, int disable);
void vgmboy_embedded_gme_enable_accuracy(vgmboy_gme_t* emu, int enabled);
const char* vgmboy_embedded_gme_track_timing(
    const vgmboy_gme_t* emu,
    int track,
    vgmboy_gme_track_timing_t* out
);

#ifdef __cplusplus
}
#endif

#endif
