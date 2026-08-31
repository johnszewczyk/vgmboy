#include "openmpt_bridge.h"

#include <libopenmpt/libopenmpt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  openmpt_module *module;
  int32_t sample_rate;
  int32_t played_frames;
  int32_t track_ended;
} OpenMPTPlayer;

static char *copy_string(const char *value) {
  if (!value || !*value) return NULL;
  size_t length = strlen(value);
  char *copy = malloc(length + 1);
  if (copy) memcpy(copy, value, length + 1);
  return copy;
}

static void set_error(char **error, const char *message) {
  if (error) *error = copy_string(message ? message : "libopenmpt decoder failure.");
}

static openmpt_module *open_module(const char *path, char **error) {
  FILE *file = fopen(path, "rb");
  if (!file) { set_error(error, "Could not open tracker module."); return NULL; }
  if (fseek(file, 0, SEEK_END) != 0) { fclose(file); set_error(error, "Could not read tracker module."); return NULL; }
  long size = ftell(file);
  if (size <= 0 || fseek(file, 0, SEEK_SET) != 0) { fclose(file); set_error(error, "Tracker module is empty or unreadable."); return NULL; }
  void *data = malloc((size_t)size);
  if (!data || fread(data, 1, (size_t)size, file) != (size_t)size) { free(data); fclose(file); set_error(error, "Could not read tracker module."); return NULL; }
  fclose(file);
  int library_error = 0;
  const char *library_message = NULL;
  openmpt_module *module = openmpt_module_create_from_memory2(data, (size_t)size, NULL, NULL, NULL, NULL, &library_error, &library_message, NULL);
  free(data);
  if (!module) {
    set_error(error, library_message ? library_message : "libopenmpt could not load this module.");
    if (library_message) openmpt_free_string(library_message);
    return NULL;
  }
  if (library_message) openmpt_free_string(library_message);
  openmpt_module_ctl_set_text(module, "play.at_end", "stop");
  return module;
}

static void fill_metadata(openmpt_module *module, openmpt_metadata_t *metadata) {
  memset(metadata, 0, sizeof(*metadata));
  metadata->title = copy_string(openmpt_module_get_metadata(module, "title"));
  metadata->artist = copy_string(openmpt_module_get_metadata(module, "artist"));
  metadata->tracker = copy_string(openmpt_module_get_metadata(module, "tracker"));
  double duration = openmpt_module_get_duration_seconds(module);
  metadata->play_length_ms = duration > 0 && duration < 2147483 ? (int32_t)(duration * 1000) : 0;
}

openmpt_player_handle_t openmpt_player_create(const char *path, int32_t sample_rate, char **error) {
  if (!path || sample_rate <= 0) { set_error(error, "Tracker playback requires a file path and sample rate."); return NULL; }
  openmpt_module *module = open_module(path, error);
  if (!module) return NULL;
  OpenMPTPlayer *player = calloc(1, sizeof(*player));
  if (!player) { openmpt_module_destroy(module); set_error(error, "Could not allocate tracker playback state."); return NULL; }
  player->module = module;
  player->sample_rate = sample_rate;
  return player;
}

void openmpt_player_destroy(openmpt_player_handle_t handle) {
  OpenMPTPlayer *player = handle;
  if (!player) return;
  if (player->module) openmpt_module_destroy(player->module);
  free(player);
}

int32_t openmpt_player_read_metadata(openmpt_player_handle_t handle, openmpt_metadata_t *metadata, char **error) {
  OpenMPTPlayer *player = handle;
  if (!player || !player->module || !metadata) { set_error(error, "Tracker decoder is not initialized."); return -1; }
  fill_metadata(player->module, metadata);
  return 0;
}

int32_t openmpt_player_set_repeat(openmpt_player_handle_t handle, int32_t enabled, char **error) {
  OpenMPTPlayer *player = handle;
  if (!player || !player->module || !openmpt_module_set_repeat_count(player->module, enabled ? -1 : 0)) { set_error(error, "Could not configure tracker repeat playback."); return -1; }
  player->track_ended = 0;
  return 0;
}

int32_t openmpt_player_seek_milliseconds(openmpt_player_handle_t handle, int32_t milliseconds, char **error) {
  OpenMPTPlayer *player = handle;
  if (!player || !player->module || milliseconds < 0) { set_error(error, "Invalid tracker seek request."); return -1; }
  openmpt_module_set_position_seconds(player->module, (double)milliseconds / 1000.0);
  player->played_frames = (int32_t)(((int64_t)milliseconds * player->sample_rate) / 1000);
  player->track_ended = 0;
  return 0;
}

int32_t openmpt_player_render_s16(openmpt_player_handle_t handle, int32_t requested, int16_t *samples, int32_t *rendered, char **error) {
  OpenMPTPlayer *player = handle;
  if (!player || !player->module || requested < 0 || (!samples && requested > 0)) { set_error(error, "Invalid tracker render request."); return -1; }
  size_t count = openmpt_module_read_interleaved_stereo(player->module, player->sample_rate, (size_t)requested, samples);
  player->played_frames += (int32_t)count;
  if (count == 0) player->track_ended = 1;
  if (rendered) *rendered = (int32_t)count;
  return 0;
}

int32_t openmpt_player_track_ended(openmpt_player_handle_t handle) { OpenMPTPlayer *player = handle; return !player || player->track_ended; }
int32_t openmpt_player_played_frames(openmpt_player_handle_t handle) { OpenMPTPlayer *player = handle; return player ? player->played_frames : 0; }
void openmpt_metadata_clear(openmpt_metadata_t *metadata) { if (!metadata) return; free(metadata->title); free(metadata->artist); free(metadata->tracker); memset(metadata, 0, sizeof(*metadata)); }
void openmpt_error_message_free(char *error) { free(error); }
