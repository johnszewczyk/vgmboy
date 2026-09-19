#include "vgmboy_asap.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "asap.h"

/* Compile the single upstream ASAP implementation from its vendored source. */
#include "asap.c"

struct VGMBoyASAPPlayer {
    ASAP *module;
};

VGMBoyASAPPlayer *vgmboy_asap_create(const uint8_t *module, int module_length, const char *filename, int sample_rate) {
    if (module == NULL || module_length <= 0 || filename == NULL || sample_rate <= 0) {
        return NULL;
    }

    VGMBoyASAPPlayer *player = (VGMBoyASAPPlayer *) malloc(sizeof(*player));
    if (player == NULL) {
        return NULL;
    }
    player->module = ASAP_New();
    if (player->module == NULL) {
        free(player);
        return NULL;
    }
    ASAP_SetSampleRate(player->module, sample_rate);
    if (!ASAP_Load(player->module, filename, module, module_length)) {
        ASAP_Delete(player->module);
        free(player);
        return NULL;
    }
    ASAP_DetectSilence(player->module, 0);
    return player;
}

void vgmboy_asap_destroy(VGMBoyASAPPlayer *player) {
    if (player != NULL) {
        ASAP_Delete(player->module);
        free(player);
    }
}

int vgmboy_asap_song_count(const VGMBoyASAPPlayer *player) {
    return player == NULL ? 0 : ASAPInfo_GetSongs(ASAP_GetInfo(player->module));
}

int vgmboy_asap_default_song(const VGMBoyASAPPlayer *player) {
    return player == NULL ? 0 : ASAPInfo_GetDefaultSong(ASAP_GetInfo(player->module));
}

int vgmboy_asap_channels(const VGMBoyASAPPlayer *player) {
    return player == NULL ? 0 : ASAPInfo_GetChannels(ASAP_GetInfo(player->module));
}

int vgmboy_asap_duration_ms(const VGMBoyASAPPlayer *player, int song) {
    return player == NULL ? -1 : ASAPInfo_GetDuration(ASAP_GetInfo(player->module), song);
}

bool vgmboy_asap_song_loops(const VGMBoyASAPPlayer *player, int song) {
    return player != NULL && ASAPInfo_GetLoop(ASAP_GetInfo(player->module), song);
}

const char *vgmboy_asap_title(const VGMBoyASAPPlayer *player) {
    return player == NULL ? "" : ASAPInfo_GetTitle(ASAP_GetInfo(player->module));
}

const char *vgmboy_asap_title_or_filename(const VGMBoyASAPPlayer *player) {
    return player == NULL ? "" : ASAPInfo_GetTitleOrFilename(ASAP_GetInfo(player->module));
}

const char *vgmboy_asap_author(const VGMBoyASAPPlayer *player) {
    return player == NULL ? "" : ASAPInfo_GetAuthor(ASAP_GetInfo(player->module));
}

bool vgmboy_asap_start_song(VGMBoyASAPPlayer *player, int song, int duration_ms) {
    return player != NULL && ASAP_PlaySong(player->module, song, duration_ms);
}

bool vgmboy_asap_seek(VGMBoyASAPPlayer *player, int position_ms) {
    return player != NULL && position_ms >= 0 && ASAP_Seek(player->module, position_ms);
}

int vgmboy_asap_render_stereo(VGMBoyASAPPlayer *player, int16_t *samples, int frame_count) {
    if (player == NULL || samples == NULL || frame_count < 0) {
        return -1;
    }
    if (frame_count == 0) {
        return 0;
    }

    const int channels = ASAPInfo_GetChannels(ASAP_GetInfo(player->module));
    if ((channels != 1 && channels != 2) || frame_count > INT_MAX / (channels * (int) sizeof(int16_t))) {
        return -1;
    }

    memset(samples, 0, (size_t) frame_count * 2 * sizeof(int16_t));
    const int byte_count = frame_count * channels * (int) sizeof(int16_t);
    const int produced_bytes = ASAP_Generate(
        player->module,
        (uint8_t *) samples,
        byte_count,
        ASAPSampleFormat_S16_L_E
    );
    if (produced_bytes < 0) {
        return -1;
    }

    const int produced_frames = produced_bytes / (channels * (int) sizeof(int16_t));
    if (channels == 1) {
        for (int index = produced_frames - 1; index >= 0; --index) {
            const int16_t mono = samples[index];
            samples[index * 2] = mono;
            samples[index * 2 + 1] = mono;
        }
    }
    return produced_frames;
}
