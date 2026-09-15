#ifndef METAMAN_ZLIB_H
#define METAMAN_ZLIB_H

#include <stddef.h>
#include <stdint.h>

/// Inflates one or more concatenated gzip members into an allocated buffer.
/// Returns 0 on success, 1 for invalid input, 2 when the output limit is
/// exceeded, and 3 when memory allocation fails. The caller releases a
/// successful output buffer with metaman_gzip_free().
int metaman_gzip_decompress(
    const uint8_t *input,
    size_t input_size,
    size_t maximum_output_size,
    uint8_t **output,
    size_t *output_size
);

void metaman_gzip_free(void *buffer);

#endif
