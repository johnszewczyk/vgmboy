#include "MetaManZlib.h"

#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

enum {
    METAMAN_GZIP_OK = 0,
    METAMAN_GZIP_INVALID = 1,
    METAMAN_GZIP_LIMIT = 2,
    METAMAN_GZIP_ALLOCATION = 3
};

static int grow_output(uint8_t **output, size_t *capacity, size_t maximum_capacity) {
    if (*capacity >= maximum_capacity) return METAMAN_GZIP_LIMIT;

    size_t next_capacity = *capacity == 0 ? 65536 : *capacity;
    if (next_capacity > maximum_capacity / 2) {
        next_capacity = maximum_capacity;
    } else {
        next_capacity *= 2;
    }
    if (next_capacity <= *capacity) return METAMAN_GZIP_LIMIT;

    uint8_t *next = (uint8_t *)realloc(*output, next_capacity);
    if (next == NULL) return METAMAN_GZIP_ALLOCATION;
    *output = next;
    *capacity = next_capacity;
    return METAMAN_GZIP_OK;
}

int metaman_gzip_decompress(
    const uint8_t *input,
    size_t input_size,
    size_t maximum_output_size,
    uint8_t **output,
    size_t *output_size
) {
    if (output == NULL || output_size == NULL) return METAMAN_GZIP_INVALID;
    *output = NULL;
    *output_size = 0;
    if (input == NULL || input_size == 0 || maximum_output_size == SIZE_MAX) {
        return METAMAN_GZIP_INVALID;
    }

    // Keep one sentinel byte beyond the caller's limit so an exact-limit
    // stream can still report Z_STREAM_END without being mistaken for an
    // oversized stream.
    const size_t maximum_capacity = maximum_output_size + 1;
    size_t capacity = maximum_capacity < 65536 ? maximum_capacity : 65536;
    if (capacity == 0) capacity = 1;
    uint8_t *buffer = (uint8_t *)malloc(capacity);
    if (buffer == NULL) return METAMAN_GZIP_ALLOCATION;

    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, MAX_WBITS + 16) != Z_OK) {
        free(buffer);
        return METAMAN_GZIP_INVALID;
    }

    size_t input_cursor = 0;
    size_t produced_total = 0;
    int result = METAMAN_GZIP_INVALID;

    for (;;) {
        if (stream.avail_in == 0 && input_cursor < input_size) {
            size_t remaining = input_size - input_cursor;
            uInt chunk_size = remaining > UINT_MAX ? UINT_MAX : (uInt)remaining;
            stream.next_in = (Bytef *)(input + input_cursor);
            stream.avail_in = chunk_size;
            input_cursor += chunk_size;
        }

        if (produced_total == capacity) {
            int grow_result = grow_output(&buffer, &capacity, maximum_capacity);
            if (grow_result != METAMAN_GZIP_OK) {
                result = grow_result;
                break;
            }
        }

        size_t available_output = capacity - produced_total;
        uInt output_chunk = available_output > UINT_MAX ? UINT_MAX : (uInt)available_output;
        stream.next_out = buffer + produced_total;
        stream.avail_out = output_chunk;

        uInt input_before = stream.avail_in;
        uInt output_before = stream.avail_out;
        int status = inflate(&stream, Z_NO_FLUSH);
        produced_total += (size_t)(output_before - stream.avail_out);

        if (produced_total > maximum_output_size) {
            result = METAMAN_GZIP_LIMIT;
            break;
        }

        if (status == Z_STREAM_END) {
            if (stream.avail_in == 0 && input_cursor == input_size) {
                result = METAMAN_GZIP_OK;
                break;
            }

            // Gzip permits concatenated members. Preserve the unread input
            // across reset so every member contributes to the same output.
            Bytef *next_input = stream.next_in;
            uInt remaining_input = stream.avail_in;
            if (inflateReset2(&stream, MAX_WBITS + 16) != Z_OK) {
                result = METAMAN_GZIP_INVALID;
                break;
            }
            stream.next_in = next_input;
            stream.avail_in = remaining_input;
            continue;
        }

        if (status != Z_OK) {
            result = METAMAN_GZIP_INVALID;
            break;
        }

        if (input_before == stream.avail_in && output_before == stream.avail_out) {
            if (stream.avail_in == 0 && input_cursor < input_size) continue;
            result = METAMAN_GZIP_INVALID;
            break;
        }
    }

    inflateEnd(&stream);
    if (result != METAMAN_GZIP_OK) {
        free(buffer);
        return result;
    }

    *output = buffer;
    *output_size = produced_total;
    return METAMAN_GZIP_OK;
}

void metaman_gzip_free(void *buffer) {
    free(buffer);
}
