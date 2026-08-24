#include "vgmboy_audio_unit.h"

#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>
#include <math.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#define VGMBOY_BAND_COUNT 10
#define VGMBOY_BYTES_PER_FRAME 4

typedef struct { float b0, b1, b2, a1, a2, x1[2], x2[2], y1[2], y2[2]; } Biquad;

struct VGMBoyAudioUnit {
  AudioComponentInstance unit;
  AudioStreamBasicDescription format;
  unsigned char* ring;
  size_t capacity_bytes;
  _Atomic uint64_t read_index, write_index;
  _Atomic int running;
  _Atomic int transport_active;
  _Atomic uint64_t callback_count, underrun_count, frames_requested, frames_supplied, frames_written;
  _Atomic float transport_gain, transport_target;
  _Atomic uint32_t transport_ramp_frames;
  pthread_mutex_t producer_lock;
  float volume;
  int mono, equalizer_enabled;
  Biquad equalizer[VGMBOY_BAND_COUNT];
};

static const float band_frequencies[VGMBOY_BAND_COUNT] = {31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000};
static float clampf(float value, float low, float high) { return value < low ? low : (value > high ? high : value); }

static void configure_biquad(Biquad* band, float frequency, float gain_db, double sample_rate) {
  const float omega = (float)(2.0 * M_PI * frequency / sample_rate), sine = sinf(omega), cosine = cosf(omega);
  const float alpha = sine * sinhf(logf(2.0f) * 0.5f * omega / (sine > 0.000001f ? sine : 0.000001f)), amplitude = powf(10.0f, gain_db / 40.0f), a0 = 1.0f + alpha / amplitude;
  band->b0 = (1.0f + alpha * amplitude) / a0; band->b1 = (-2.0f * cosine) / a0; band->b2 = (1.0f - alpha * amplitude) / a0;
  band->a1 = (-2.0f * cosine) / a0; band->a2 = (1.0f - alpha / amplitude) / a0;
}
static float process_sample(Biquad* band, float input, int channel) {
  const float output = band->b0 * input + band->b1 * band->x1[channel] + band->b2 * band->x2[channel] - band->a1 * band->y1[channel] - band->a2 * band->y2[channel];
  band->x2[channel] = band->x1[channel]; band->x1[channel] = input; band->y2[channel] = band->y1[channel]; band->y1[channel] = output; return output;
}
static size_t readable(const VGMBoyAudioUnit* output) {
  const uint64_t write = atomic_load_explicit(&output->write_index, memory_order_acquire), read = atomic_load_explicit(&output->read_index, memory_order_acquire), bytes = write - read;
  return bytes > output->capacity_bytes ? 0 : (size_t)bytes;
}
static void copy_into(VGMBoyAudioUnit* output, uint64_t index, const unsigned char* source, size_t count) {
  const size_t offset = (size_t)(index % output->capacity_bytes), first = count < output->capacity_bytes - offset ? count : output->capacity_bytes - offset;
  memcpy(output->ring + offset, source, first); if (count > first) memcpy(output->ring, source + first, count - first);
}
static void copy_out(const VGMBoyAudioUnit* output, uint64_t index, unsigned char* destination, size_t count) {
  const size_t offset = (size_t)(index % output->capacity_bytes), first = count < output->capacity_bytes - offset ? count : output->capacity_bytes - offset;
  memcpy(destination, output->ring + offset, first); if (count > first) memcpy(destination + first, output->ring, count - first);
}
static size_t ring_write(VGMBoyAudioUnit* output, const void* source, size_t count) {
  const uint64_t write = atomic_load_explicit(&output->write_index, memory_order_relaxed), read = atomic_load_explicit(&output->read_index, memory_order_acquire), used = write - read;
  if (used > output->capacity_bytes) return 0;
  const size_t actual = count < output->capacity_bytes - (size_t)used ? count : output->capacity_bytes - (size_t)used;
  if (!actual) return 0; copy_into(output, write, source, actual); atomic_store_explicit(&output->write_index, write + actual, memory_order_release); return actual;
}
static size_t ring_read(VGMBoyAudioUnit* output, void* destination, size_t count) {
  const uint64_t read = atomic_load_explicit(&output->read_index, memory_order_relaxed), write = atomic_load_explicit(&output->write_index, memory_order_acquire), available = write - read;
  if (available > output->capacity_bytes) return 0;
  const size_t actual = count < (size_t)available ? count : (size_t)available;
  if (!actual) return 0; copy_out(output, read, destination, actual); uint64_t expected = read;
  return atomic_compare_exchange_strong_explicit(&output->read_index, &expected, read + actual, memory_order_release, memory_order_relaxed) ? actual : 0;
}

static void render_frames(VGMBoyAudioUnit* output, int16_t* samples, uint32_t frames) {
  const uint32_t bytes = frames * VGMBOY_BYTES_PER_FRAME;
  atomic_fetch_add_explicit(&output->callback_count, 1, memory_order_relaxed); atomic_fetch_add_explicit(&output->frames_requested, frames, memory_order_relaxed);
  const int active = atomic_load_explicit(&output->transport_active, memory_order_acquire);
  const size_t supplied_bytes = active ? ring_read(output, samples, bytes) : 0;
  atomic_fetch_add_explicit(&output->frames_supplied, supplied_bytes / VGMBOY_BYTES_PER_FRAME, memory_order_relaxed);
  if (supplied_bytes < bytes) {
    memset((unsigned char*)samples + supplied_bytes, 0, bytes - supplied_bytes);
    if (active) atomic_fetch_add_explicit(&output->underrun_count, 1, memory_order_relaxed);
  }
  float gain = atomic_load_explicit(&output->transport_gain, memory_order_acquire), target = atomic_load_explicit(&output->transport_target, memory_order_acquire); uint32_t remaining = atomic_load_explicit(&output->transport_ramp_frames, memory_order_acquire);
  for (UInt32 frame = 0; frame < frames; frame += 1) { gain = remaining ? gain + (target - gain) / (float)remaining-- : target; const size_t index = (size_t)frame * 2; samples[index] = (int16_t)lrintf(clampf((float)samples[index] * gain, -32768, 32767)); samples[index + 1] = (int16_t)lrintf(clampf((float)samples[index + 1] * gain, -32768, 32767)); }
  atomic_store_explicit(&output->transport_gain, gain, memory_order_release); atomic_store_explicit(&output->transport_ramp_frames, remaining, memory_order_release);
}
static OSStatus render(void* context, AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp, UInt32 bus, UInt32 frames, AudioBufferList* buffers) {
  (void)flags; (void)timestamp; (void)bus;
  VGMBoyAudioUnit* output = context;
  if (!output || !buffers || !buffers->mNumberBuffers) return noErr;
  AudioBuffer* buffer = &buffers->mBuffers[0]; const uint32_t bytes = frames * VGMBOY_BYTES_PER_FRAME;
  if (!buffer->mData || buffer->mDataByteSize < bytes) return noErr;
  render_frames(output, buffer->mData, frames); buffer->mDataByteSize = bytes; return noErr;
}
static int prepare_unit(VGMBoyAudioUnit* output) {
  if (output->unit) return 0; AudioComponentDescription description = {0}; description.componentType = kAudioUnitType_Output; description.componentSubType = kAudioUnitSubType_DefaultOutput; description.componentManufacturer = kAudioUnitManufacturer_Apple;
  AudioComponent component = AudioComponentFindNext(NULL, &description); if (!component || AudioComponentInstanceNew(component, &output->unit) != noErr) return 1;
  AURenderCallbackStruct callback = {.inputProc = render, .inputProcRefCon = output};
  if (AudioUnitSetProperty(output->unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, sizeof(callback)) != noErr) return 1;
  if (AudioUnitSetProperty(output->unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &output->format, sizeof(output->format)) != noErr) return 1;
  return AudioUnitInitialize(output->unit) == noErr ? 0 : 1;
}
int vgmboy_audio_unit_create(VGMBoyAudioUnit** result, const VGMBoyAudioUnitConfig* config) {
  if (!result || !config || config->sample_rate <= 0 || config->channel_count != 2 || !config->ring_buffer_frames) return 1;
  VGMBoyAudioUnit* output = calloc(1, sizeof(*output)); if (!output) return 1; output->capacity_bytes = (size_t)config->ring_buffer_frames * VGMBOY_BYTES_PER_FRAME; output->ring = calloc(output->capacity_bytes, 1);
  if (!output->ring || pthread_mutex_init(&output->producer_lock, NULL)) { free(output->ring); free(output); return 1; }
  output->format.mSampleRate = config->sample_rate; output->format.mFormatID = kAudioFormatLinearPCM; output->format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked; output->format.mFramesPerPacket = 1; output->format.mChannelsPerFrame = 2; output->format.mBitsPerChannel = 16; output->format.mBytesPerFrame = VGMBOY_BYTES_PER_FRAME; output->format.mBytesPerPacket = VGMBOY_BYTES_PER_FRAME; output->volume = 1;
  atomic_init(&output->transport_active, 0); atomic_init(&output->transport_gain, 1); atomic_init(&output->transport_target, 1); atomic_init(&output->transport_ramp_frames, 0);
  for (size_t i = 0; i < VGMBOY_BAND_COUNT; i += 1) configure_biquad(&output->equalizer[i], band_frequencies[i], 0, config->sample_rate); *result = output; return 0;
}
void vgmboy_audio_unit_destroy(VGMBoyAudioUnit* output) { if (!output) return; if (output->unit) { AudioOutputUnitStop(output->unit); AudioUnitUninitialize(output->unit); AudioComponentInstanceDispose(output->unit); } pthread_mutex_destroy(&output->producer_lock); free(output->ring); free(output); }
int vgmboy_audio_unit_start(VGMBoyAudioUnit* output) { if (!output) return 1; if (atomic_load_explicit(&output->running, memory_order_acquire)) return 0; if (prepare_unit(output) || AudioOutputUnitStart(output->unit) != noErr) return 1; atomic_store_explicit(&output->running, 1, memory_order_release); return 0; }
int vgmboy_audio_unit_stop(VGMBoyAudioUnit* output) { if (!output) return 1; if (!atomic_load_explicit(&output->running, memory_order_acquire)) return 0; if (AudioOutputUnitStop(output->unit) != noErr) return 1; atomic_store_explicit(&output->running, 0, memory_order_release); return 0; }
void vgmboy_audio_unit_clear(VGMBoyAudioUnit* output) { if (output) atomic_store_explicit(&output->read_index, atomic_load_explicit(&output->write_index, memory_order_relaxed), memory_order_release); }
void vgmboy_audio_unit_reset_counters(VGMBoyAudioUnit* output) { if (output) { atomic_store(&output->callback_count, 0); atomic_store(&output->underrun_count, 0); atomic_store(&output->frames_requested, 0); atomic_store(&output->frames_supplied, 0); atomic_store(&output->frames_written, 0); } }
void vgmboy_audio_unit_set_volume(VGMBoyAudioUnit* output, float volume) { if (output) { pthread_mutex_lock(&output->producer_lock); output->volume = clampf(volume, 0, 1); pthread_mutex_unlock(&output->producer_lock); } }
void vgmboy_audio_unit_set_mono(VGMBoyAudioUnit* output, int enabled) { if (output) { pthread_mutex_lock(&output->producer_lock); output->mono = enabled != 0; pthread_mutex_unlock(&output->producer_lock); } }
void vgmboy_audio_unit_set_transport_gain(VGMBoyAudioUnit* output, float gain) { if (output) { const float safe = clampf(gain, 0, 1); atomic_store(&output->transport_gain, safe); atomic_store(&output->transport_target, safe); atomic_store(&output->transport_ramp_frames, 0); } }
void vgmboy_audio_unit_set_transport_active(VGMBoyAudioUnit* output, int active) { if (output) atomic_store_explicit(&output->transport_active, active != 0, memory_order_release); }
void vgmboy_audio_unit_ramp_transport_gain(VGMBoyAudioUnit* output, float gain, uint32_t frames) { if (output) { atomic_store(&output->transport_target, clampf(gain, 0, 1)); atomic_store(&output->transport_ramp_frames, frames); } }
void vgmboy_audio_unit_set_equalizer(VGMBoyAudioUnit* output, int enabled, const float* gains, size_t count) { if (!output) return; pthread_mutex_lock(&output->producer_lock); output->equalizer_enabled = enabled != 0; for (size_t i = 0; i < VGMBOY_BAND_COUNT; i += 1) { configure_biquad(&output->equalizer[i], band_frequencies[i], gains && i < count ? clampf(gains[i], -12, 12) : 0, output->format.mSampleRate); memset(output->equalizer[i].x1, 0, sizeof(output->equalizer[i].x1)); memset(output->equalizer[i].x2, 0, sizeof(output->equalizer[i].x2)); memset(output->equalizer[i].y1, 0, sizeof(output->equalizer[i].y1)); memset(output->equalizer[i].y2, 0, sizeof(output->equalizer[i].y2)); } pthread_mutex_unlock(&output->producer_lock); }
size_t vgmboy_audio_unit_enqueue_pcm(VGMBoyAudioUnit* output, int16_t* samples, size_t frames) { if (!output || !samples) return 0; pthread_mutex_lock(&output->producer_lock); for (size_t frame = 0; frame < frames; frame += 1) { float left = samples[frame * 2] / 32768.0f, right = samples[frame * 2 + 1] / 32768.0f; if (output->equalizer_enabled) for (size_t band = 0; band < VGMBOY_BAND_COUNT; band += 1) { left = process_sample(&output->equalizer[band], left, 0); right = process_sample(&output->equalizer[band], right, 1); } if (output->mono) { const float mix = (left + right) * 0.5f; left = mix; right = mix; } samples[frame * 2] = (int16_t)lrintf(clampf(left * output->volume, -1, 1) * 32767); samples[frame * 2 + 1] = (int16_t)lrintf(clampf(right * output->volume, -1, 1) * 32767); } pthread_mutex_unlock(&output->producer_lock); const size_t written = ring_write(output, samples, frames * VGMBOY_BYTES_PER_FRAME) / VGMBOY_BYTES_PER_FRAME; atomic_fetch_add_explicit(&output->frames_written, written, memory_order_relaxed); return written; }
size_t vgmboy_audio_unit_render_offline(VGMBoyAudioUnit* output, int16_t* samples, size_t frames) { if (!output || !samples || !frames || frames > UINT32_MAX) return 0; render_frames(output, samples, (uint32_t)frames); return frames; }
int vgmboy_audio_unit_snapshot(const VGMBoyAudioUnit* output, VGMBoyAudioUnitSnapshot* snapshot) { if (!output || !snapshot) return 1; snapshot->is_running = atomic_load(&output->running); snapshot->callback_count = atomic_load(&output->callback_count); snapshot->underrun_count = atomic_load(&output->underrun_count); snapshot->frames_requested = atomic_load(&output->frames_requested); snapshot->frames_supplied = atomic_load(&output->frames_supplied); snapshot->frames_written = atomic_load(&output->frames_written); snapshot->buffered_frames = (uint32_t)(readable(output) / VGMBOY_BYTES_PER_FRAME); snapshot->ring_buffer_frames = (uint32_t)(output->capacity_bytes / VGMBOY_BYTES_PER_FRAME); snapshot->sample_rate = output->format.mSampleRate; return 0; }
