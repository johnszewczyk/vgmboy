#include "sidplayfp_bridge.h"

#include <sidplayfp/SidConfig.h>
#include <sidplayfp/SidTune.h>
#include <sidplayfp/SidTuneInfo.h>
#include <sidplayfp/builders/sidlite.h>
#include <sidplayfp/sidplayfp.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <new>
#include <string>
#include <vector>

namespace {

constexpr int32_t kDefaultSampleRate = 44100;
constexpr uint32_t kCpuClockPAL = 985248;
constexpr uint32_t kCpuClockNTSC = 1022727;
constexpr uint32_t kRenderFramesChunk = 4096;

struct SidPlayer {
  SidTune* tune = nullptr;
  SIDLiteBuilder* builder = nullptr;
  sidplayfp player;
  uint32_t cpuClock = kCpuClockPAL;
  int32_t sampleRate = kDefaultSampleRate;
  int64_t playedFrames = 0;
  std::vector<short> overflow;
  size_t overflowConsumed = 0;
};

char* duplicate(const char* value) {
  if (!value) return nullptr;
  const size_t size = std::strlen(value) + 1;
  char* copy = static_cast<char*>(std::malloc(size));
  if (copy) std::memcpy(copy, value, size);
  return copy;
}

void setError(char** errorMessage, const std::string& message) {
  if (!errorMessage) return;
  std::free(*errorMessage);
  *errorMessage = duplicate(message.c_str());
}

std::string playerError(sidplayfp& player) {
  const char* message = player.error();
  return message ? message : "SID playback error";
}

uint32_t cpuClock(const SidTuneInfo* info) {
  return info && info->clockSpeed() == SidTuneInfo::CLOCK_NTSC ? kCpuClockNTSC : kCpuClockPAL;
}

SidPlayer* openPlayer(const char* path, int32_t sampleRate, char** errorMessage) {
  if (!path) {
    setError(errorMessage, "SID path is required");
    return nullptr;
  }
  SidPlayer* result = new (std::nothrow) SidPlayer();
  if (!result) {
    setError(errorMessage, "Out of memory creating SID player");
    return nullptr;
  }
  result->sampleRate = sampleRate > 0 ? sampleRate : kDefaultSampleRate;
  result->tune = new (std::nothrow) SidTune(path);
  if (!result->tune || !result->tune->getStatus()) {
    setError(errorMessage, std::string("Unable to load SID tune: ") + path);
    delete result->tune;
    delete result;
    return nullptr;
  }
  result->cpuClock = cpuClock(result->tune->getInfo());
  result->builder = new (std::nothrow) SIDLiteBuilder("vgmboy-sidlite");
  if (!result->builder) {
    setError(errorMessage, "Out of memory creating SID emulator");
    delete result->tune;
    delete result;
    return nullptr;
  }
  SidConfig config;
  config.frequency = result->sampleRate;
  config.samplingMethod = SidConfig::RESAMPLE_INTERPOLATE;
  config.defaultC64Model = SidConfig::PAL;
  config.forceC64Model = false;
  config.defaultSidModel = SidConfig::MOS6581;
  config.forceSidModel = false;
  config.sidEmulation = result->builder;
  if (!result->player.config(config) || !result->player.load(result->tune)) {
    setError(errorMessage, playerError(result->player));
    delete result->builder;
    delete result->tune;
    delete result;
    return nullptr;
  }
  return result;
}

}  // namespace

extern "C" vgmboy_sid_handle_t vgmboy_sid_open(const char* path, int32_t sample_rate, char** error_message) {
  return openPlayer(path, sample_rate, error_message);
}

extern "C" void vgmboy_sid_close(vgmboy_sid_handle_t handle) {
  SidPlayer* player = static_cast<SidPlayer*>(handle);
  if (!player) return;
  delete player->builder;
  delete player->tune;
  delete player;
}

extern "C" int32_t vgmboy_sid_read_metadata(vgmboy_sid_handle_t handle, vgmboy_sid_metadata_t* metadata, char** error_message) {
  SidPlayer* player = static_cast<SidPlayer*>(handle);
  if (!player || !metadata || !player->tune) {
    setError(error_message, "SID metadata is unavailable");
    return 1;
  }
  const SidTuneInfo* info = player->tune->getInfo();
  if (!info) {
    setError(error_message, "SID tune metadata is unavailable");
    return 1;
  }
  vgmboy_sid_metadata_clear(metadata);
  metadata->title = duplicate(info->numberOfInfoStrings() > 0 ? info->infoString(0) : nullptr);
  metadata->artist = duplicate(info->numberOfInfoStrings() > 1 ? info->infoString(1) : nullptr);
  metadata->comment = duplicate(info->numberOfInfoStrings() > 2 ? info->infoString(2) : nullptr);
  metadata->system = duplicate("Commodore 64");
  return 0;
}

extern "C" int32_t vgmboy_sid_render_s16(vgmboy_sid_handle_t handle, int32_t requested_frames, int16_t* samples, int32_t* rendered_frames, char** error_message) {
  SidPlayer* player = static_cast<SidPlayer*>(handle);
  if (!player || requested_frames < 0 || !samples) {
    setError(error_message, "SID render request is invalid");
    return 1;
  }
  int32_t rendered = 0;
  while (rendered < requested_frames) {
    if (player->overflowConsumed < player->overflow.size()) {
      const int32_t take = static_cast<int32_t>(std::min<size_t>(
        player->overflow.size() - player->overflowConsumed,
        static_cast<size_t>(requested_frames - rendered)
      ));
      for (int32_t index = 0; index < take; ++index) {
        const short sample = player->overflow[player->overflowConsumed + index];
        samples[(rendered + index) * 2] = sample;
        samples[(rendered + index) * 2 + 1] = sample;
      }
      player->overflowConsumed += take;
      rendered += take;
      continue;
    }
    const uint32_t cycles = static_cast<uint32_t>((static_cast<uint64_t>(kRenderFramesChunk) * player->cpuClock) / player->sampleRate);
    short* monoBuffer = nullptr;
    player->player.buffers(&monoBuffer);
    const int produced = player->player.play(cycles);
    if (produced <= 0) {
      if (produced < 0) setError(error_message, playerError(player->player));
      break;
    }
    player->overflow.assign(monoBuffer, monoBuffer + produced);
    player->overflowConsumed = 0;
  }
  player->playedFrames += rendered;
  if (rendered_frames) *rendered_frames = rendered;
  return 0;
}

extern "C" int32_t vgmboy_sid_seek_milliseconds(vgmboy_sid_handle_t handle, int32_t milliseconds, char** error_message) {
  SidPlayer* player = static_cast<SidPlayer*>(handle);
  if (!player) {
    setError(error_message, "SID player is unavailable");
    return 1;
  }
  player->overflow.clear();
  player->overflowConsumed = 0;
  if (!player->player.reset()) {
    setError(error_message, playerError(player->player));
    return 1;
  }
  const int32_t safeMilliseconds = std::max<int32_t>(0, milliseconds);
  if (safeMilliseconds > 0) {
    const uint64_t frames = (static_cast<uint64_t>(safeMilliseconds) * player->sampleRate) / 1000;
    const uint32_t cycles = static_cast<uint32_t>((frames * player->cpuClock) / player->sampleRate);
    short* monoBuffer = nullptr;
    player->player.buffers(&monoBuffer);
    if (player->player.play(cycles) < 0) {
      setError(error_message, playerError(player->player));
      return 1;
    }
  }
  player->playedFrames = (static_cast<int64_t>(safeMilliseconds) * player->sampleRate) / 1000;
  return 0;
}

extern "C" int64_t vgmboy_sid_played_frames(vgmboy_sid_handle_t handle) {
  SidPlayer* player = static_cast<SidPlayer*>(handle);
  return player ? player->playedFrames : 0;
}

extern "C" void vgmboy_sid_metadata_clear(vgmboy_sid_metadata_t* metadata) {
  if (!metadata) return;
  std::free(metadata->title); metadata->title = nullptr;
  std::free(metadata->artist); metadata->artist = nullptr;
  std::free(metadata->comment); metadata->comment = nullptr;
  std::free(metadata->system); metadata->system = nullptr;
}

extern "C" void vgmboy_sid_free_string(char* string) {
  std::free(string);
}
