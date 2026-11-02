#include "vgmboy_zstd_decompress.h"
#include "zstd.h"
#include <limits.h>

long vgmboy_zstd_frame_content_size(const void* src, size_t src_size) {
    unsigned long long const size = ZSTD_getFrameContentSize(src, src_size);
    if (size == ZSTD_CONTENTSIZE_UNKNOWN || size == ZSTD_CONTENTSIZE_ERROR) {
        return -1;
    }
    if (size > (unsigned long long)LONG_MAX) {
        return -2;
    }
    return (long)size;
}

long vgmboy_zstd_decompress_frame(
    void* dst,
    size_t dst_capacity,
    const void* src,
    size_t src_size
) {
    size_t const result = ZSTD_decompress(dst, dst_capacity, src, src_size);
    if (ZSTD_isError(result)) {
        return -(long)result;
    }
    return (long)result;
}

const char* vgmboy_zstd_error_name(long code) {
    if (code >= 0) {
        return "No error";
    }
    size_t const raw = (size_t)(-code);
    return ZSTD_getErrorName(raw);
}
