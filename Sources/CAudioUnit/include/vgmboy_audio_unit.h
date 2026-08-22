#ifndef VGMBOY_AUDIO_UNIT_H
#define VGMBOY_AUDIO_UNIT_H

#include <stddef.h>
#include <stdint.h>

typedef struct VGMBoyAudioUnit VGMBoyAudioUnit;

typedef struct VGMBoyAudioUnitConfig {
  double sample_rate;
  uint32_t channel_count;
  uint32_t callback_frames;
  uint32_t ring_buffer_frames;
} VGMBoyAudioUnitConfig;

typedef struct VGMBoyAudioUnitSnapshot {
  int is_running;
  uint64_t callback_count;
  uint64_t underrun_count;
  uint64_t frames_requested;
  uint64_t frames_supplied;
  uint64_t frames_written;
  uint32_t buffered_frames;
  uint32_t ring_buffer_frames;
  double sample_rate;
} VGMBoyAudioUnitSnapshot;

int vgmboy_audio_unit_create(VGMBoyAudioUnit** output, const VGMBoyAudioUnitConfig* config);
void vgmboy_audio_unit_destroy(VGMBoyAudioUnit* output);
int vgmboy_audio_unit_start(VGMBoyAudioUnit* output);
int vgmboy_audio_unit_stop(VGMBoyAudioUnit* output);
void vgmboy_audio_unit_clear(VGMBoyAudioUnit* output);
void vgmboy_audio_unit_reset_counters(VGMBoyAudioUnit* output);
void vgmboy_audio_unit_set_volume(VGMBoyAudioUnit* output, float volume);
void vgmboy_audio_unit_set_mono(VGMBoyAudioUnit* output, int enabled);
void vgmboy_audio_unit_set_equalizer(VGMBoyAudioUnit* output, int enabled, const float* gains, size_t gain_count);
void vgmboy_audio_unit_set_transport_gain(VGMBoyAudioUnit* output, float gain);
void vgmboy_audio_unit_ramp_transport_gain(VGMBoyAudioUnit* output, float gain, uint32_t frame_count);
size_t vgmboy_audio_unit_enqueue_pcm(VGMBoyAudioUnit* output, int16_t* interleaved_stereo, size_t frame_count);
int vgmboy_audio_unit_snapshot(const VGMBoyAudioUnit* output, VGMBoyAudioUnitSnapshot* snapshot);

#endif
