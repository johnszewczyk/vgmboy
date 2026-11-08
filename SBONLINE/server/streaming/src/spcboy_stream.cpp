#include "libvgm_bridge.h"

#include <gme/gme.h>

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>

namespace {

constexpr int kSampleRate = 44100;
constexpr int kChunkFrames = 4096;

bool isVgm(const char* path) {
    std::string value(path);
    const auto dot = value.find_last_of('.');
    if (dot == std::string::npos) return false;
    value = value.substr(dot + 1);
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return value == "vgm" || value == "vgz";
}

bool isSpc(const char* path) {
    std::string value(path);
    const auto dot = value.find_last_of('.');
    if (dot == std::string::npos) return false;
    value = value.substr(dot + 1);
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return value == "spc";
}

bool writeFrames(const int16_t* samples, int frames) {
    if (frames <= 0) return true;
    if (std::fwrite(samples, sizeof(int16_t) * 2, static_cast<size_t>(frames), stdout)
        != static_cast<size_t>(frames)) {
        return false;
    }
    return std::fflush(stdout) == 0;
}

int64_t outputFramesForSourceMilliseconds(int sourceMs, int numerator, int denominator) {
    const int64_t scaledFrames = static_cast<int64_t>(sourceMs) * kSampleRate * denominator;
    const int64_t frameDenominator = 1000LL * numerator;
    return (scaledFrames + frameDenominator - 1) / frameDenominator;
}

void applyLinearFade(
    int16_t* samples,
    int frames,
    int64_t firstOutputFrame,
    int startMs,
    int playMs,
    int fadeMs,
    int numerator,
    int denominator
) {
    if (fadeMs <= 0) return;
    const double speed = static_cast<double>(numerator) / denominator;
    const double fadeEndMs = static_cast<double>(playMs) + fadeMs;

    for (int frame = 0; frame < frames; ++frame) {
        const double sourcePositionMs = startMs
            + (static_cast<double>(firstOutputFrame + frame) * 1000.0 / kSampleRate) * speed;
        if (sourcePositionMs < playMs) continue;
        const double gain = sourcePositionMs >= fadeEndMs
            ? 0.0
            : (fadeEndMs - sourcePositionMs) / fadeMs;
        for (int channel = 0; channel < 2; ++channel) {
            const int sampleIndex = frame * 2 + channel;
            samples[sampleIndex] = static_cast<int16_t>(std::lround(samples[sampleIndex] * gain));
        }
    }
}

int streamVgm(
    const char* path,
    int index,
    int playMs,
    int fadeMs,
    int startMs,
    bool longPlay,
    int speedNumerator,
    int speedDenominator
) {
    char* error = nullptr;
    auto handle = libvgm_player_create(path, kSampleRate, index, &error);
    if (!handle) {
        std::fprintf(stderr, "libvgm open failed: %s\n", error ? error : "unknown error");
        libvgm_error_message_free(error);
        return 1;
    }
    if (libvgm_player_configure(handle, longPlay ? 86400 : playMs / 1000, longPlay ? 0 : fadeMs / 1000, false, &error) != 0) {
        std::fprintf(stderr, "libvgm configure failed: %s\n", error ? error : "unknown error");
        libvgm_error_message_free(error);
        libvgm_player_destroy(handle);
        return 1;
    }
    auto applyPlaybackSpeed = [&]() {
        if (libvgm_player_set_playback_speed(handle, speedNumerator, speedDenominator, &error) == 0) return true;
        std::fprintf(stderr, "libvgm speed setup failed: %s\n", error ? error : "unknown error");
        libvgm_error_message_free(error);
        error = nullptr;
        return false;
    };
    if (startMs > 0 && libvgm_player_seek_milliseconds(handle, startMs, &error) != 0) {
        std::fprintf(stderr, "libvgm seek failed: %s\n", error ? error : "unknown error");
        libvgm_error_message_free(error);
        libvgm_player_destroy(handle);
        return 1;
    }
    if (!applyPlaybackSpeed()) {
        libvgm_player_destroy(handle);
        return 1;
    }

    libvgm_metadata_t metadata {};
    if (libvgm_player_read_metadata(handle, &metadata, &error) != 0) {
        std::fprintf(stderr, "libvgm metadata failed: %s\n", error ? error : "unknown error");
        libvgm_error_message_free(error);
        libvgm_player_destroy(handle);
        return 1;
    }
    const bool hasNativeLoop = metadata.loop_length_ms > 0;
    libvgm_metadata_clear(&metadata);

    const int remainingMs = std::max(0, playMs + fadeMs - startMs);
    int64_t remainingFrames = outputFramesForSourceMilliseconds(remainingMs, speedNumerator, speedDenominator);
    int16_t samples[kChunkFrames * 2];
    int64_t outputFrame = 0;
    bool reopenedForLongPlay = false;
    auto reopenTrack = [&](const char* action) {
        libvgm_player_destroy(handle);
        handle = libvgm_player_create(path, kSampleRate, index, &error);
        if (!handle) {
            std::fprintf(stderr, "%s failed: %s\n", action, error ? error : "unknown error");
            libvgm_error_message_free(error);
            return false;
        }
        if (libvgm_player_configure(handle, longPlay ? 86400 : playMs / 1000, longPlay ? 0 : fadeMs / 1000, false, &error) != 0) {
            std::fprintf(stderr, "libvgm configure failed: %s\n", error ? error : "unknown error");
            libvgm_error_message_free(error);
            libvgm_player_destroy(handle);
            handle = nullptr;
            return false;
        }
        if (!applyPlaybackSpeed()) {
            libvgm_player_destroy(handle);
            handle = nullptr;
            return false;
        }
        return true;
    };
    while (remainingFrames > 0) {
        if (libvgm_player_track_ended(handle)) {
            if (!longPlay) break;
            if (hasNativeLoop) {
                std::fprintf(stderr, "libvgm ended unexpectedly inside a native loop\n");
                libvgm_player_destroy(handle);
                return 1;
            }
            if (!reopenTrack("libvgm reopen")) return 1;
            reopenedForLongPlay = true;
        }
        const int wanted = static_cast<int>(std::min<int64_t>(kChunkFrames, remainingFrames));
        int rendered = 0;
        if (libvgm_player_render_s16(handle, wanted, samples, &rendered, &error) != 0) {
            std::fprintf(stderr, "libvgm render failed: %s\n", error ? error : "unknown error");
            libvgm_error_message_free(error);
            libvgm_player_destroy(handle);
            return 1;
        }
        if (rendered <= 0) {
            if (longPlay && hasNativeLoop) {
                std::fprintf(stderr, "libvgm produced no frames inside a native loop\n");
                libvgm_player_destroy(handle);
                return 1;
            }
            // Some libVGM cores return no frames at the boundary before their
            // ended flag becomes visible. A zero-frame render is the boundary;
            // reopen once, while treating an empty reopened track as invalid.
            if (longPlay && !hasNativeLoop && !reopenedForLongPlay) {
                if (!reopenTrack("libvgm restart")) return 1;
                reopenedForLongPlay = true;
                continue;
            }
            break;
        }
        reopenedForLongPlay = false;
        applyLinearFade(samples, rendered, outputFrame, startMs, playMs, fadeMs, speedNumerator, speedDenominator);
        if (!writeFrames(samples, rendered)) {
            libvgm_player_destroy(handle);
            return errno == EPIPE ? 0 : 1;
        }
        remainingFrames -= rendered;
        outputFrame += rendered;
    }
    libvgm_player_destroy(handle);
    return 0;
}

int streamGme(
    const char* path,
    int index,
    int playMs,
    int fadeMs,
    int startMs,
    bool longPlay,
    int speedNumerator,
    int speedDenominator
) {
    const bool fixedLengthSpc = isSpc(path);
    Music_Emu* emu = nullptr;
    const char* error = gme_open_file(path, &emu, kSampleRate);
    if (error) {
        std::fprintf(stderr, "libgme open failed: %s\n", error);
        return 1;
    }
    if (index >= gme_track_count(emu)) {
        std::fprintf(stderr, "track index is outside the file's track count\n");
        gme_delete(emu);
        return 1;
    }
    gme_set_autoload_playback_limit(emu, 0);
    if (fixedLengthSpc || longPlay) {
        // Fixed-length SPC playback and Long Play use the requested stream
        // duration; native metadata limits and silence detection must not end
        // these streams early.
        gme_ignore_silence(emu, 1);
    }
    error = gme_start_track(emu, index);
    if (error) {
        std::fprintf(stderr, "libgme start failed: %s\n", error);
        gme_delete(emu);
        return 1;
    }
    // libgme has its own fixed fade length. Use our absolute output envelope
    // for every format so the requested fade duration is honored exactly.
    gme_set_fade(emu, std::numeric_limits<int>::max() / 2);
    if (startMs > 0) {
        error = gme_seek(emu, startMs);
        if (error) {
            std::fprintf(stderr, "libgme seek failed: %s\n", error);
            gme_delete(emu);
            return 1;
        }
    }
    const double speed = static_cast<double>(speedNumerator) / speedDenominator;
    gme_set_tempo(emu, speed);

    const int remainingMs = std::max(0, playMs + fadeMs - startMs);
    int64_t remainingFrames = outputFramesForSourceMilliseconds(remainingMs, speedNumerator, speedDenominator);
    int64_t outputFrame = 0;
    int16_t samples[kChunkFrames * 2];
    while (remainingFrames > 0) {
        if (gme_track_ended(emu)) {
            if (longPlay && !fixedLengthSpc) {
                error = gme_start_track(emu, index);
                if (error) {
                    std::fprintf(stderr, "libgme restart failed: %s\n", error);
                    gme_delete(emu);
                    return 1;
                }
                gme_set_fade(emu, std::numeric_limits<int>::max() / 2);
                gme_set_tempo(emu, speed);
            } else if (!fixedLengthSpc) {
                break;
            }
        }
        const int wanted = static_cast<int>(std::min<int64_t>(kChunkFrames, remainingFrames));
        error = gme_play(emu, wanted * 2, samples);
        if (error) {
            std::fprintf(stderr, "libgme render failed: %s\n", error);
            gme_delete(emu);
            return 1;
        }
        applyLinearFade(samples, wanted, outputFrame, startMs, playMs, fadeMs, speedNumerator, speedDenominator);
        if (!writeFrames(samples, wanted)) {
            gme_delete(emu);
            return errno == EPIPE ? 0 : 1;
        }
        remainingFrames -= wanted;
        outputFrame += wanted;
    }
    gme_delete(emu);
    return 0;
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 9) {
        std::fprintf(stderr, "usage: spcboy-stream <source> <track-index> <play-ms> <fade-ms> <start-ms> <long-play:0|1> <speed-numerator> <speed-denominator>\n");
        return 2;
    }
    char* end = nullptr;
    const long index = std::strtol(argv[2], &end, 10);
    if (*end != '\0' || index < 0 || index > std::numeric_limits<int>::max()) return 2;
    const long playMs = std::strtol(argv[3], &end, 10);
    if (*end != '\0' || playMs <= 0 || playMs > 24L * 60 * 60 * 1000) return 2;
    const long fadeMs = std::strtol(argv[4], &end, 10);
    if (*end != '\0' || fadeMs < 0 || fadeMs > 120000) return 2;
    const long startMs = std::strtol(argv[5], &end, 10);
    if (*end != '\0' || startMs < 0 || startMs > playMs + fadeMs) return 2;
    const long longPlayValue = std::strtol(argv[6], &end, 10);
    if (*end != '\0' || (longPlayValue != 0 && longPlayValue != 1)) return 2;
    const long speedNumerator = std::strtol(argv[7], &end, 10);
    if (*end != '\0' || speedNumerator < 1 || speedNumerator > 128) return 2;
    const long speedDenominator = std::strtol(argv[8], &end, 10);
    if (*end != '\0' || speedDenominator < 1 || speedDenominator > 128) return 2;
    const long speedTicks = speedNumerator * 64;
    if (speedTicks % speedDenominator != 0 || speedTicks / speedDenominator < 32 || speedTicks / speedDenominator > 128) return 2;
    const bool longPlay = longPlayValue == 1;
    std::setvbuf(stdout, nullptr, _IONBF, 0);
    return isVgm(argv[1])
        ? streamVgm(argv[1], static_cast<int>(index), static_cast<int>(playMs), static_cast<int>(fadeMs), static_cast<int>(startMs), longPlay, static_cast<int>(speedNumerator), static_cast<int>(speedDenominator))
        : streamGme(argv[1], static_cast<int>(index), static_cast<int>(playMs), static_cast<int>(fadeMs), static_cast<int>(startMs), longPlay, static_cast<int>(speedNumerator), static_cast<int>(speedDenominator));
}
