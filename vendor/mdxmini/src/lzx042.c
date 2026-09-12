/*
 * X68000 MDX/PDX LZX decoder.
 *
 * This is a C port of the GPL-2.0 lzx042.nas implementation by Mamiya,
 * mirrored by FIX94/in_mdx. The X68000 0.32 and 0.42 containers use the same
 * bitstream instructions; only the visible version tag differs.
 */

#include "lzx042.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define X68K_LZX_MAX_OUTPUT ((size_t)512 * 1024 * 1024)

static const unsigned char k_lzx_marker[4] = {0x7f, 0xff, 0xff, 0x4c};

typedef struct {
    const unsigned char *source;
    size_t length;
    size_t offset;
    unsigned int bit_count;
    unsigned int current;
} lzx_bit_reader;

typedef struct {
    unsigned char *bytes;
    size_t length;
    size_t capacity;
} lzx_output;

static int read_byte(lzx_bit_reader *reader, unsigned int *value) {
    if (!reader || !value || reader->offset >= reader->length) return -1;
    *value = reader->source[reader->offset++];
    return 0;
}

static int read_bit(lzx_bit_reader *reader, unsigned int *value) {
    if (!reader || !value) return -1;
    if (reader->bit_count == 0) {
        if (read_byte(reader, &reader->current) != 0) return -1;
        reader->bit_count = 8;
    }
    reader->bit_count--;
    *value = (reader->current & 0x80U) != 0;
    reader->current = (reader->current << 1) & 0xffU;
    return 0;
}

static int append_byte(lzx_output *output, unsigned char value) {
    if (!output || output->length >= X68K_LZX_MAX_OUTPUT) return -1;
    if (output->length == output->capacity) {
        size_t new_capacity = output->capacity == 0 ? 4096 : output->capacity * 2;
        if (new_capacity < output->capacity || new_capacity > X68K_LZX_MAX_OUTPUT) {
            new_capacity = X68K_LZX_MAX_OUTPUT;
        }
        unsigned char *bytes = (unsigned char *)realloc(output->bytes, new_capacity);
        if (!bytes) return -1;
        output->bytes = bytes;
        output->capacity = new_capacity;
    }
    output->bytes[output->length++] = value;
    return 0;
}

static int copy_history(lzx_output *output, int32_t offset, size_t length) {
    if (!output || offset >= 0) return -1;
    int64_t source_index = (int64_t)output->length + offset;
    if (source_index < 0) return -1;

    for (size_t index = 0; index < length; index++) {
        if (source_index < 0 || (uint64_t)source_index >= output->length) return -1;
        unsigned char value = output->bytes[source_index++];
        if (append_byte(output, value) != 0) return -1;
    }
    return 0;
}

static int has_marker_at(const unsigned char *source, size_t length, size_t offset) {
    return source && offset <= length && length - offset >= sizeof(k_lzx_marker)
        && memcmp(source + offset, k_lzx_marker, sizeof(k_lzx_marker)) == 0;
}

static int find_stream_offset(
    const unsigned char *source,
    size_t length,
    size_t *stream_offset
) {
    if (!source || !stream_offset) return -1;

    size_t offset = 0x24;
    while (offset <= length && length - offset >= 2 + sizeof(k_lzx_marker)) {
        offset += 2;
        if (has_marker_at(source, length, offset)) {
            *stream_offset = offset + sizeof(k_lzx_marker);
            return 0;
        }
    }

    for (offset = 0; offset <= length && length - offset >= sizeof(k_lzx_marker); offset++) {
        if (has_marker_at(source, length, offset)) {
            *stream_offset = offset + sizeof(k_lzx_marker);
            return 0;
        }
    }
    return -1;
}

int x68k_lzx_looks_like(const unsigned char *source, size_t source_length) {
    if (!source || source_length < 12) return 0;
    if (source[0] != 0x60 || source[1] != 0x26 || source[2] != 0x60) return 0;
    if (source[3] != 0x32 && source[3] != 0x4a) return 0;
    if (memcmp(source + 4, "LZX ", 4) != 0) return 0;
    return source[8] == '0' && source[9] == '.'
        && (source[10] == '3' || source[10] == '4')
        && source[11] >= '0' && source[11] <= '9';
}

int x68k_lzx_decode(
    const unsigned char *source,
    size_t source_length,
    unsigned char **output,
    size_t *output_length
) {
    if (!source || !output || !output_length || !x68k_lzx_looks_like(source, source_length)) {
        return -1;
    }

    *output = NULL;
    *output_length = 0;

    size_t stream_offset = 0;
    if (find_stream_offset(source, source_length, &stream_offset) != 0) return -1;

    size_t expected_length = 0;
    if (source_length >= 0x16) {
        expected_length = ((size_t)source[0x12] << 24)
            | ((size_t)source[0x13] << 16)
            | ((size_t)source[0x14] << 8)
            | (size_t)source[0x15];
        if (expected_length > X68K_LZX_MAX_OUTPUT) return -1;
    }

    lzx_output decoded = {0};
    lzx_bit_reader reader = {
        .source = source,
        .length = source_length,
        .offset = stream_offset,
        .bit_count = 8,
        .current = 0
    };
    if (read_byte(&reader, &reader.current) != 0) return -1;

    for (;;) {
        unsigned int bit = 0;
        if (read_bit(&reader, &bit) != 0) goto failure;
        if (bit != 0) {
            unsigned int value = 0;
            if (read_byte(&reader, &value) != 0 || append_byte(&decoded, (unsigned char)value) != 0) {
                goto failure;
            }
            continue;
        }

        if (read_bit(&reader, &bit) != 0) goto failure;
        if (bit == 0) {
            unsigned int code = 0;
            unsigned int distance = 0;
            if (read_bit(&reader, &bit) != 0) goto failure;
            code = bit << 1;
            if (read_bit(&reader, &bit) != 0) goto failure;
            code |= bit;
            if (read_byte(&reader, &distance) != 0
                || copy_history(&decoded, (int32_t)distance - 256, (size_t)code + 2) != 0) {
                goto failure;
            }
            continue;
        }

        unsigned int high = 0;
        unsigned int low = 0;
        if (read_byte(&reader, &high) != 0 || read_byte(&reader, &low) != 0) goto failure;
        int32_t packed = (int32_t)((high << 8) | low);
        /* The original 68K implementation starts with -1, writes AH/AL,
         * then arithmetic-shifts the resulting 0xffffxxxx word. This is a
         * fixed 16-bit signed container, not a normal sign-extension test on
         * bit 15. */
        int32_t offset = ((int32_t)0xffff0000U | packed) >> 3;
        unsigned int code = low & 0x07U;
        if (code != 0) {
            if (copy_history(&decoded, offset, (size_t)code + 2) != 0) goto failure;
            continue;
        }

        unsigned int extra = 0;
        if (read_byte(&reader, &extra) != 0) goto failure;
        if (extra == 0) break;
        if (copy_history(&decoded, offset, (size_t)extra + 1) != 0) goto failure;
    }

    if (expected_length != 0 && decoded.length != expected_length) goto failure;
    *output = decoded.bytes;
    *output_length = decoded.length;
    return 0;

failure:
    free(decoded.bytes);
    return -1;
}
