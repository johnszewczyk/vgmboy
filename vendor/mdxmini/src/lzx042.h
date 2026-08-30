/*
 * X68000 MDX/PDX LZX decoder.
 *
 * The stream decoder is a C port of the GPL-2.0 lzx042.nas implementation by
 * Mamiya, mirrored by FIX94/in_mdx. X68000 MDX collections use the same
 * stream rules for the 0.32 and 0.42 headers.
 */

#ifndef __X68K_LZX042_H__
#define __X68K_LZX042_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Returns non-zero when the input begins with an X68000 LZX container tag. */
int x68k_lzx_looks_like(const unsigned char *source, size_t source_length);

/* The caller owns *output and must free it after a successful decode. */
int x68k_lzx_decode(
    const unsigned char *source,
    size_t source_length,
    unsigned char **output,
    size_t *output_length
);

#ifdef __cplusplus
}
#endif

#endif
