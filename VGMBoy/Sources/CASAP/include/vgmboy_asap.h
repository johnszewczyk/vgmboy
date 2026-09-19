#ifndef VGMBoy_CASAP_H
#define VGMBoy_CASAP_H

#include <stdbool.h>
#include <stdint.h>

typedef struct VGMBoyASAPPlayer VGMBoyASAPPlayer;

VGMBoyASAPPlayer *vgmboy_asap_create(const uint8_t *module, int module_length, const char *filename, int sample_rate);
void vgmboy_asap_destroy(VGMBoyASAPPlayer *player);

int vgmboy_asap_song_count(const VGMBoyASAPPlayer *player);
int vgmboy_asap_default_song(const VGMBoyASAPPlayer *player);
int vgmboy_asap_channels(const VGMBoyASAPPlayer *player);
int vgmboy_asap_duration_ms(const VGMBoyASAPPlayer *player, int song);
bool vgmboy_asap_song_loops(const VGMBoyASAPPlayer *player, int song);
const char *vgmboy_asap_title(const VGMBoyASAPPlayer *player);
const char *vgmboy_asap_title_or_filename(const VGMBoyASAPPlayer *player);
const char *vgmboy_asap_author(const VGMBoyASAPPlayer *player);

bool vgmboy_asap_start_song(VGMBoyASAPPlayer *player, int song, int duration_ms);
bool vgmboy_asap_seek(VGMBoyASAPPlayer *player, int position_ms);
int vgmboy_asap_render_stereo(VGMBoyASAPPlayer *player, int16_t *samples, int frame_count);

#endif
