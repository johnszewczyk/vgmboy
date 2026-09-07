#include "vgmboy_zxtune.h"

#include "binary/container_factories.h"
#include "core/plugins/player_plugins_registrator.h"
#include "core/plugins/players/ay/aym_plugin.h"
#include "error.h"
#include "module/attributes.h"
#include "module/players/pipeline.h"
#include "parameters/container.h"
#include "sound/sound_parameters.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <memory>
#include <string>
#include <vector>

namespace ZXTune {
void RegisterASCSupport(PlayerPluginsRegistrator &);
void RegisterFTCSupport(PlayerPluginsRegistrator &);
void RegisterGTRSupport(PlayerPluginsRegistrator &);
void RegisterPSCSupport(PlayerPluginsRegistrator &);
void RegisterPSMSupport(PlayerPluginsRegistrator &);
void RegisterPSGSupport(PlayerPluginsRegistrator &);
void RegisterPT1Support(PlayerPluginsRegistrator &);
void RegisterPT2Support(PlayerPluginsRegistrator &);
void RegisterPT3Support(PlayerPluginsRegistrator &);
void RegisterSQTSupport(PlayerPluginsRegistrator &);
void RegisterST1Support(PlayerPluginsRegistrator &);
void RegisterST3Support(PlayerPluginsRegistrator &);
void RegisterSTCSupport(PlayerPluginsRegistrator &);
void RegisterSTPSupport(PlayerPluginsRegistrator &);
void RegisterVTXSupport(PlayerPluginsRegistrator &);
void RegisterYMSupport(PlayerPluginsRegistrator &);
} // namespace ZXTune

namespace {

class AYPluginRegistry final : public ZXTune::PlayerPluginsRegistrator {
public:
    void RegisterPlugin(ZXTune::PlayerPlugin::Ptr plugin) override {
        plugins.push_back(std::move(plugin));
    }

    std::vector<ZXTune::PlayerPlugin::Ptr> plugins;
};

const std::vector<ZXTune::PlayerPlugin::Ptr> &ay_plugins() {
    static const auto plugins = [] {
        AYPluginRegistry registry;
        ZXTune::RegisterASCSupport(registry);
        ZXTune::RegisterFTCSupport(registry);
        ZXTune::RegisterGTRSupport(registry);
        ZXTune::RegisterPSCSupport(registry);
        ZXTune::RegisterPSMSupport(registry);
        ZXTune::RegisterPSGSupport(registry);
        ZXTune::RegisterPT1Support(registry);
        ZXTune::RegisterPT2Support(registry);
        ZXTune::RegisterPT3Support(registry);
        ZXTune::RegisterSQTSupport(registry);
        ZXTune::RegisterST1Support(registry);
        ZXTune::RegisterST3Support(registry);
        ZXTune::RegisterSTCSupport(registry);
        ZXTune::RegisterSTPSupport(registry);
        ZXTune::RegisterVTXSupport(registry);
        ZXTune::RegisterYMSupport(registry);
        return registry.plugins;
    }();
    return plugins;
}

void set_error(char **destination, const std::string &message) {
    if (!destination) {
        return;
    }
    const auto size = message.size();
    auto *copy = static_cast<char *>(std::malloc(size + 1));
    if (!copy) {
        *destination = nullptr;
        return;
    }
    std::memcpy(copy, message.data(), size);
    copy[size] = '\0';
    *destination = copy;
}

char *copy_string(const std::string &source) {
    auto *destination = static_cast<char *>(std::malloc(source.size() + 1));
    if (!destination) {
        return nullptr;
    }
    std::memcpy(destination, source.data(), source.size());
    destination[source.size()] = '\0';
    return destination;
}

std::string property(const Parameters::Accessor &properties, Parameters::Identifier name) {
    return Parameters::GetString(properties, name);
}

} // namespace

struct vgmboy_zxtune_player {
    Module::Holder::Ptr module;
    Parameters::Container::Ptr render_parameters;
    Module::Renderer::Ptr renderer;
    std::vector<Sound::Sample> pending;
    size_t pending_offset = 0;
    int sample_rate = 44100;
    int64_t played_frames = 0;
    bool ended = false;
    bool looped = false;

    void rebuild_renderer() {
        render_parameters = Parameters::Container::Create();
        render_parameters->SetValue(Parameters::ZXTune::Sound::FREQUENCY, sample_rate);
        render_parameters->SetValue(Parameters::ZXTune::Sound::LOOPED, looped ? 1 : 0);
        render_parameters->SetValue(Parameters::ZXTune::Sound::LOOP_LIMIT, 0);
        renderer = Module::CreatePipelinedRenderer(*module, sample_rate, render_parameters);
        pending.clear();
        pending_offset = 0;
        ended = false;
    }
};

extern "C" vgmboy_zxtune_player_t *vgmboy_zxtune_player_create(const char *path,
                                                                  int32_t sample_rate,
                                                                  char **error_message) {
    if (error_message) {
        *error_message = nullptr;
    }
    if (!path || !*path) {
        set_error(error_message, "ZXTune path is empty.");
        return nullptr;
    }
    try {
        std::ifstream input(path, std::ios::binary);
        if (!input) {
            set_error(error_message, "Could not open the ZXTune source file.");
            return nullptr;
        }
        std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(input)),
                                   std::istreambuf_iterator<char>());
        if (bytes.empty()) {
            set_error(error_message, "ZXTune source file is empty.");
            return nullptr;
        }

        auto *player = new vgmboy_zxtune_player();
        player->sample_rate = std::max<int32_t>(1, sample_rate);
        auto data = Binary::CreateContainer(Binary::View(bytes));
        const auto parameters = Parameters::Container::Create();
        for (const auto &plugin : ay_plugins()) {
            player->module = plugin->TryOpen(*parameters, *data, Parameters::Container::Create());
            if (player->module) {
                break;
            }
        }
        if (!player->module) {
            set_error(error_message, "ZXTune did not recognize this AY-family source file.");
            delete player;
            return nullptr;
        }
        player->rebuild_renderer();
        return player;
    } catch (const Error &error) {
        set_error(error_message, error.ToString());
    } catch (const std::exception &error) {
        set_error(error_message, error.what());
    } catch (...) {
        set_error(error_message, "ZXTune failed to open the source file.");
    }
    return nullptr;
}

extern "C" void vgmboy_zxtune_player_destroy(vgmboy_zxtune_player_t *player) {
    delete player;
}

extern "C" int32_t vgmboy_zxtune_player_read_metadata(vgmboy_zxtune_player_t *player,
                                                         vgmboy_zxtune_metadata_t *metadata,
                                                         char **error_message) {
    if (error_message) {
        *error_message = nullptr;
    }
    if (!player || !metadata) {
        set_error(error_message, "ZXTune metadata request is invalid.");
        return -1;
    }
    try {
        vgmboy_zxtune_metadata_clear(metadata);
        const auto properties = player->module->GetModuleProperties();
        metadata->title = copy_string(property(*properties, Module::ATTR_TITLE));
        metadata->author = copy_string(property(*properties, Module::ATTR_AUTHOR));
        metadata->program = copy_string(property(*properties, Module::ATTR_PROGRAM));
        auto system = property(*properties, Module::ATTR_PLATFORM);
        if (system.empty()) {
            system = property(*properties, Module::ATTR_COMPUTER);
        }
        metadata->system = copy_string(system);
        const auto info = player->module->GetModuleInformation();
        metadata->length_ms = static_cast<int32_t>(std::max<int64_t>(0, info.Duration.Get()));
        metadata->loop_ms = static_cast<int32_t>(std::max<int64_t>(0, info.LoopDuration.Get()));
        return 0;
    } catch (const Error &error) {
        set_error(error_message, error.ToString());
    } catch (const std::exception &error) {
        set_error(error_message, error.what());
    } catch (...) {
        set_error(error_message, "ZXTune metadata is unavailable.");
    }
    return -1;
}

extern "C" void vgmboy_zxtune_metadata_clear(vgmboy_zxtune_metadata_t *metadata) {
    if (!metadata) {
        return;
    }
    std::free(metadata->title);
    std::free(metadata->author);
    std::free(metadata->program);
    std::free(metadata->system);
    std::memset(metadata, 0, sizeof(*metadata));
}

extern "C" int32_t vgmboy_zxtune_player_set_looped(vgmboy_zxtune_player_t *player,
                                                      int32_t enabled,
                                                      char **error_message) {
    if (error_message) {
        *error_message = nullptr;
    }
    if (!player) {
        set_error(error_message, "ZXTune loop request is invalid.");
        return -1;
    }
    try {
        player->looped = enabled != 0;
        player->rebuild_renderer();
        return 0;
    } catch (const Error &error) {
        set_error(error_message, error.ToString());
    } catch (const std::exception &error) {
        set_error(error_message, error.what());
    } catch (...) {
        set_error(error_message, "ZXTune could not configure looping.");
    }
    return -1;
}

extern "C" int32_t vgmboy_zxtune_player_seek(vgmboy_zxtune_player_t *player,
                                                int32_t milliseconds,
                                                char **error_message) {
    if (error_message) {
        *error_message = nullptr;
    }
    if (!player || !player->renderer) {
        set_error(error_message, "ZXTune seek request is invalid.");
        return -1;
    }
    try {
        player->renderer->SetPosition(Time::AtMillisecond(std::max<int32_t>(0, milliseconds)));
        player->pending.clear();
        player->pending_offset = 0;
        player->ended = false;
        return 0;
    } catch (const Error &error) {
        set_error(error_message, error.ToString());
    } catch (const std::exception &error) {
        set_error(error_message, error.what());
    } catch (...) {
        set_error(error_message, "ZXTune could not seek.");
    }
    return -1;
}

extern "C" int32_t vgmboy_zxtune_player_render(vgmboy_zxtune_player_t *player,
                                                  int32_t frame_count,
                                                  int16_t *interleaved,
                                                  int32_t *rendered_frames,
                                                  char **error_message) {
    if (error_message) {
        *error_message = nullptr;
    }
    if (rendered_frames) {
        *rendered_frames = 0;
    }
    if (!player || !interleaved || !rendered_frames || frame_count < 0) {
        set_error(error_message, "ZXTune render request is invalid.");
        return -1;
    }
    try {
        int32_t written = 0;
        while (written < frame_count) {
            if (player->pending_offset >= player->pending.size()) {
                auto chunk = player->renderer->Render();
                if (chunk.empty()) {
                    player->ended = true;
                    break;
                }
                player->pending = std::move(chunk);
                player->pending_offset = 0;
            }
            const auto available = player->pending.size() - player->pending_offset;
            const auto count = std::min<size_t>(available, static_cast<size_t>(frame_count - written));
            for (size_t index = 0; index < count; ++index) {
                const auto &sample = player->pending[player->pending_offset + index];
                interleaved[(written + static_cast<int32_t>(index)) * 2] = static_cast<int16_t>(sample.Left());
                interleaved[(written + static_cast<int32_t>(index)) * 2 + 1] = static_cast<int16_t>(sample.Right());
            }
            player->pending_offset += count;
            written += static_cast<int32_t>(count);
        }
        player->played_frames += written;
        *rendered_frames = written;
        return 0;
    } catch (const Error &error) {
        set_error(error_message, error.ToString());
    } catch (const std::exception &error) {
        set_error(error_message, error.what());
    } catch (...) {
        set_error(error_message, "ZXTune could not render audio.");
    }
    return -1;
}

extern "C" int32_t vgmboy_zxtune_player_track_ended(const vgmboy_zxtune_player_t *player) {
    return player && player->ended ? 1 : 0;
}

extern "C" int64_t vgmboy_zxtune_player_played_frames(const vgmboy_zxtune_player_t *player) {
    return player ? player->played_frames : 0;
}

extern "C" void vgmboy_zxtune_error_message_free(char *message) {
    std::free(message);
}
