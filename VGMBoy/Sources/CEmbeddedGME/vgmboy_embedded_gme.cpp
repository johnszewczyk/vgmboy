#include "vgmboy_embedded_gme.h"
#include "gme.h"
#include <string.h>

static inline gme_t* unwrap_gme(vgmboy_gme_t* handle) {
    return reinterpret_cast<gme_t*>(handle);
}

static inline const gme_t* unwrap_gme_const(const vgmboy_gme_t* handle) {
    return reinterpret_cast<const gme_t*>(handle);
}

static void copy_cstr(char* dst, size_t dst_size, const char* src) {
    if (!dst || dst_size == 0) {
        return;
    }
    if (!src) {
        dst[0] = '\0';
        return;
    }
    strncpy(dst, src, dst_size - 1);
    dst[dst_size - 1] = '\0';
}

extern "C" {

const char* vgmboy_embedded_gme_open_data(
    const void* data,
    long size,
    vgmboy_gme_t** out,
    int sample_rate
) {
    if (!out) {
        return "Null output pointer";
    }
    gme_t* raw = nullptr;
    gme_err_t err = gme_open_data(data, size, &raw, sample_rate);
    *out = reinterpret_cast<vgmboy_gme_t*>(raw);
    return err;
}

void vgmboy_embedded_gme_delete(vgmboy_gme_t* emu) {
    if (emu) {
        gme_delete(unwrap_gme(emu));
    }
}

int vgmboy_embedded_gme_track_count(const vgmboy_gme_t* emu) {
    return emu ? gme_track_count(unwrap_gme_const(emu)) : 0;
}

const char* vgmboy_embedded_gme_start_track(vgmboy_gme_t* emu, int index) {
    return emu ? gme_start_track(unwrap_gme(emu), index) : "Invalid emulator";
}

const char* vgmboy_embedded_gme_play(vgmboy_gme_t* emu, int sample_count, short* out) {
    return emu ? gme_play(unwrap_gme(emu), sample_count, out) : "Invalid emulator";
}

const char* vgmboy_embedded_gme_seek(vgmboy_gme_t* emu, int msec) {
    return emu ? gme_seek(unwrap_gme(emu), msec) : "Invalid emulator";
}

int vgmboy_embedded_gme_tell(const vgmboy_gme_t* emu) {
    return emu ? gme_tell(unwrap_gme_const(emu)) : 0;
}

int vgmboy_embedded_gme_track_ended(const vgmboy_gme_t* emu) {
    return emu ? gme_track_ended(unwrap_gme_const(emu)) : 1;
}

void vgmboy_embedded_gme_set_tempo(vgmboy_gme_t* emu, double tempo) {
    if (emu) {
        gme_set_tempo(unwrap_gme(emu), tempo);
    }
}

void vgmboy_embedded_gme_set_fade(vgmboy_gme_t* emu, int start_msec, int length_msec) {
    if (emu) {
        gme_set_fade(unwrap_gme(emu), start_msec, length_msec);
    }
}

void vgmboy_embedded_gme_ignore_silence(vgmboy_gme_t* emu, int disable) {
    if (emu) {
        gme_ignore_silence(unwrap_gme(emu), disable);
    }
}

void vgmboy_embedded_gme_enable_accuracy(vgmboy_gme_t* emu, int enabled) {
    (void)emu;
    (void)enabled;
    // Vendored Higan SPC700/DSP core is cycle-accurate by default.
}

const char* vgmboy_embedded_gme_track_timing(
    const vgmboy_gme_t* emu,
    int track,
    vgmboy_gme_track_timing_t* out
) {
    if (!emu || !out) {
        return "Invalid arguments";
    }
    memset(out, 0, sizeof(*out));
    gme_info_t* info = nullptr;
    gme_err_t err = gme_track_info(unwrap_gme_const(emu), &info, track);
    if (err) {
        return err;
    }
    out->length_ms = info->length;
    out->intro_length_ms = info->intro_length;
    out->loop_length_ms = info->loop_length;
    out->play_length_ms = info->play_length;
    copy_cstr(out->system_name, sizeof(out->system_name), info->system);
    copy_cstr(out->game_name, sizeof(out->game_name), info->game);
    copy_cstr(out->song_name, sizeof(out->song_name), info->song);
    copy_cstr(out->author_name, sizeof(out->author_name), info->author);
    gme_free_info(info);
    return nullptr;
}

} // extern "C"
