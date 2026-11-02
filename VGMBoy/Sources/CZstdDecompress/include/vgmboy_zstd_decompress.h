#ifndef VGMBOY_ZSTD_DECOMPRESS_H
#define VGMBOY_ZSTD_DECOMPRESS_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Returns the expected decompressed byte count encoded in the Zstandard frame header,
/// or a negative value when unknown or invalid.
long vgmboy_zstd_frame_content_size(const void* src, size_t src_size);

/// Decompresses a Zstandard frame into `dst` (capacity `dst_capacity`).
/// Returns the decompressed byte count (>= 0) on success, or a negative error code on failure.
long vgmboy_zstd_decompress_frame(
    void* dst,
    size_t dst_capacity,
    const void* src,
    size_t src_size
);

/// Returns a human-readable error message for a negative return value from `vgmboy_zstd_decompress_frame`.
const char* vgmboy_zstd_error_name(long code);

#ifdef __cplusplus
}
#endif

#endif
