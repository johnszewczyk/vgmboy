#include "vgmboy_zxtune.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>

namespace {

void print_json_string(const char *value) {
    std::putchar('"');
    for (const auto *cursor = value ? value : ""; *cursor; ++cursor) {
        switch (*cursor) {
        case '"': std::fputs("\\\"", stdout); break;
        case '\\': std::fputs("\\\\", stdout); break;
        case '\n': std::fputs("\\n", stdout); break;
        case '\r': std::fputs("\\r", stdout); break;
        case '\t': std::fputs("\\t", stdout); break;
        default: std::putchar(*cursor); break;
        }
    }
    std::putchar('"');
}

int fail(const char *message) {
    std::fprintf(stderr, "vgmboy-zxtune-inspect: %s\n", message ? message : "inspection failed");
    return 1;
}

} // namespace

int main(int argc, char **argv) {
    if (argc != 2) {
        return fail("usage: vgmboy-zxtune-inspect <file>");
    }
    char *error = nullptr;
    auto *player = vgmboy_zxtune_player_create(argv[1], 44100, &error);
    if (!player) {
        const auto result = fail(error);
        vgmboy_zxtune_error_message_free(error);
        return result;
    }

    vgmboy_zxtune_metadata_t metadata{};
    if (vgmboy_zxtune_player_read_metadata(player, &metadata, &error) != 0) {
        const auto result = fail(error);
        vgmboy_zxtune_error_message_free(error);
        vgmboy_zxtune_player_destroy(player);
        return result;
    }
    std::fputs("{\"artist\":", stdout);
    print_json_string(metadata.author);
    std::fputs(",\"introLengthMs\":", stdout);
    std::printf("%d", std::max(0, metadata.length_ms - metadata.loop_ms));
    std::fputs(",\"loopLengthMs\":", stdout);
    std::printf("%d", std::max(0, metadata.loop_ms));
    std::fputs(",\"playLengthMs\":", stdout);
    std::printf("%d", std::max(0, metadata.length_ms));
    std::fputs(",\"program\":", stdout);
    print_json_string(metadata.program);
    std::fputs(",\"system\":", stdout);
    print_json_string(metadata.system);
    std::fputs(",\"title\":", stdout);
    print_json_string(metadata.title);
    std::fputs(",\"trackCount\":1}\n", stdout);

    vgmboy_zxtune_metadata_clear(&metadata);
    vgmboy_zxtune_player_destroy(player);
    return 0;
}
