/*
  MDXplay : MDX file parser

  Made by Daisuke Nagano <breeze.nagano@nifty.ne.jp>
  Jan.13.1999

  reference : mdxform.doc  ( KOUNO Takeshi )
            : MXDRVWIN.pas ( monlight@tkb.att.ne.jp )
 */

#include <stdio.h>
#include <stdlib.h>

#include <string.h>

#include "version.h"
#include "mdx.h"
#include "lzx042.h"

/* ------------------------------------------------------------------ */

static void*
__alloc_mdxwork(void)
{
  MDX_DATA* mdx = NULL;
  mdx = (MDX_DATA *)malloc(sizeof(MDX_DATA));
  if (mdx) {
    memset((void *)mdx, 0, sizeof(MDX_DATA));
  }
  return mdx;
}

/* Replace an X68000 LZX-compressed MDX body while preserving its clear text
 * title and PDX dependency header. A return value below zero means that a
 * recognized LZX body was malformed; zero means the body was plain. */
static int
__normalize_mdx_lzx(unsigned char **buffer, int *length)
{
  unsigned char *source = *buffer;
  int source_length = *length;
  int title_end = -1;
  int header_end = -1;
  int i;

  for (i = 0; i + 2 < source_length; i++) {
    if (source[i] == 0x0d && source[i + 1] == 0x0a && source[i + 2] == 0x1a) {
      title_end = i;
      break;
    }
  }
  if (title_end < 0) return 0;

  for (i = title_end + 3; i < source_length; i++) {
    if (source[i] == 0) {
      header_end = i + 1;
      break;
    }
  }
  if (header_end < 0 || header_end >= source_length
      || !x68k_lzx_looks_like(source + header_end, (size_t)(source_length - header_end))) {
    return 0;
  }

  unsigned char *decoded = NULL;
  size_t decoded_length = 0;
  if (x68k_lzx_decode(
          source + header_end,
          (size_t)(source_length - header_end),
          &decoded,
          &decoded_length) != 0
      || decoded_length > 0x7fffffffU - (size_t)header_end) {
    free(decoded);
    return -1;
  }

  size_t expanded_length = (size_t)header_end + decoded_length;
  unsigned char *expanded = (unsigned char *)malloc(expanded_length + 16);
  if (!expanded) {
    free(decoded);
    return -1;
  }
  memcpy(expanded, source, (size_t)header_end);
  memcpy(expanded + header_end, decoded, decoded_length);
  memset(expanded + expanded_length, 0, 16);
  free(decoded);
  free(source);
  *buffer = expanded;
  *length = (int)expanded_length;
  return 1;
}

static int
__load_file(MDX_DATA* mdx, char* fnam)
{
  FILE* fp = NULL;
  unsigned char* buf = NULL;
  long file_length = 0;
  int len = 0;
  int result = 0;

  fp = fopen( fnam, "rb" );
  if ( fp == NULL ) {
    return FLAG_FALSE;
  }

  fseek(fp, 0, SEEK_END);
  file_length = ftell(fp);
  if (file_length < 0 || file_length > 0x7fffffffL) {
    fclose(fp);
    return FLAG_FALSE;
  }
  len = (int)file_length;
  fseek(fp, 0, SEEK_SET);

  buf = (unsigned char *)malloc(sizeof(unsigned char)*(len+16));
  if (!buf) {
    fclose(fp);
    return FLAG_FALSE;
  }
  memset(buf, 0, (size_t)len + 16);


  result = (int)fread( buf, 1, len, fp );
  fclose(fp);
	


  if (result!=len) {
    free(buf);
    return FLAG_FALSE;
  }

  if (__normalize_mdx_lzx(&buf, &len) < 0) {
    free(buf);
    return FLAG_FALSE;
  }

  mdx->length = len;
  mdx->data = buf;

  return FLAG_TRUE;
}

MDX_DATA *mdx_open_mdx( char *name ) {

  int i,j;
  int ptr;
  unsigned char *buf;
  MDX_DATA *mdx;

  /* allocate work area */

  mdx = __alloc_mdxwork();
  if ( mdx == NULL ) return NULL;

  /* data read */
  if (!__load_file(mdx, name)) {
    goto error_end;
  }

  /* title parsing */

  for ( i=0 ; i<MDX_MAX_TITLE_LENGTH ; i++ ) {
    mdx->data_title[i] = '\0';
  }
  i=0;
  ptr=0;
  buf = mdx->data;
  mdx->data_title[i]=0;
  if (mdx->length<3) {
    goto error_end;
  }
  while (ptr + 2 < mdx->length) {
    if ( buf[ptr+0] == 0x0d &&
	 buf[ptr+1] == 0x0a &&
	 buf[ptr+2] == 0x1a ) break;

    mdx->data_title[i++]=buf[ptr++];  /* warning! this text is SJIS */
    if ( i>=MDX_MAX_TITLE_LENGTH ) i--;
  }
  if (ptr + 2 >= mdx->length) goto error_end;
  mdx->data_title[i++]=0;


  /* pdx name */

  ptr+=3;
  for ( i=0 ; i<MDX_MAX_PDX_FILENAME_LENGTH ; i++ ) {
    mdx->pdx_name[i]='\0';
  }
  i=0;
  j=0;
  mdx->haspdx=FLAG_FALSE;
  while (ptr < mdx->length) {
    if ( buf[ptr] == 0x00 ) break;

    if (i >= MDX_MAX_PDX_FILENAME_LENGTH - 5) goto error_end;
    mdx->haspdx=FLAG_TRUE;
    mdx->pdx_name[i++] = buf[ptr++];
    if ( strcasecmp( ".pdx", (char *)(buf+ptr-1) )==0 ) j=1;
  }
  if (ptr >= mdx->length) goto error_end;
  if ( mdx->haspdx==FLAG_TRUE && j==0 ) {
    if (i > MDX_MAX_PDX_FILENAME_LENGTH - 5) goto error_end;
    mdx->pdx_name[i+0] = '.';
    mdx->pdx_name[i+1] = 'p';
    mdx->pdx_name[i+2] = 'd';
    mdx->pdx_name[i+3] = 'x';
  }

  /* Older MDX writers used a leading backslash for a same-directory PDX
   * basename. Normalize only that legacy spelling; the host materializer
   * keeps its normal traversal checks for every other path spelling. */
  if (mdx->pdx_name[0] == '\\') {
    int start = 0;
    while (mdx->pdx_name[start] == '\\') start++;
    if (mdx->pdx_name[start] == '\0') goto error_end;
    memmove(mdx->pdx_name, mdx->pdx_name + start,
            strlen(mdx->pdx_name + start) + 1);
  }

  /* get voice data offset */

  ptr++;
  if (ptr + 3 >= mdx->length) goto error_end;
  mdx->base_pointer = ptr;
  mdx->voice_data_offset =
    (unsigned int)buf[ptr+0]*256 +
    (unsigned int)buf[ptr+1] + mdx->base_pointer;

  if ( mdx->voice_data_offset >= mdx->length ) goto error_end;

   /* get MML data offset */

  mdx->mml_data_offset[0] =
    (unsigned int)buf[ptr+2+0] * 256 +
    (unsigned int)buf[ptr+2+1] + mdx->base_pointer;
  if ( mdx->mml_data_offset[0] >= mdx->length ) goto error_end;

  if ( buf[mdx->mml_data_offset[0]] == MDX_SET_PCM8_MODE ) {
    mdx->ispcm8mode = 1;
    mdx->tracks = 16;
  } else {
    mdx->ispcm8mode = 0;
    mdx->tracks = 9;
  }

  for ( i=0 ; i<mdx->tracks ; i++ ) {
    mdx->mml_data_offset[i] =
      (unsigned int)buf[ptr+i*2+2+0] * 256 +
      (unsigned int)buf[ptr+i*2+2+1] + mdx->base_pointer;
    if ( mdx->mml_data_offset[i] >= mdx->length ) goto error_end;
  }


  /* init. configuration */

  mdx->is_use_pcm8 = FLAG_TRUE;
  mdx->is_use_fm   = FLAG_TRUE;
  mdx->is_use_opl3 = FLAG_TRUE;

  i = strlen(VERSION_TEXT1);
  if ( i > MDX_VERSION_TEXT_SIZE ) i=MDX_VERSION_TEXT_SIZE;
  strncpy( (char *)mdx->version_1, VERSION_TEXT1, i );
  i = strlen(VERSION_TEXT2);
  if ( i > MDX_VERSION_TEXT_SIZE ) i=MDX_VERSION_TEXT_SIZE;
  strncpy( (char *)mdx->version_2, VERSION_TEXT2, i );

  return mdx;

error_end:
  if (mdx) {
    if (mdx->data) {
      free(mdx->data);
      mdx->data = NULL;
    }

    free(mdx);
  }
  return NULL;
}

int mdx_close_mdx ( MDX_DATA *mdx ) {

  if ( mdx == NULL ) return 1;

  if ( mdx->data != NULL ) free(mdx->data);
  free(mdx);

  return 0;
}


#ifndef HAVE_SUPPORT_DUMP_VOICES
# define dump_voices(a,b) (1)
#else
static void
dump_voices(MDX_DATA* mdx, int num)
{
  int sum = 0;
  int i=0;

  fprintf(stdout, "( @%03d, \n", num);
  fprintf(stdout, "#\t AR  D1R  D2R   RR   SL   TL   KS  MUL  DT1  DT2  AME\n");
  for ( i=0 ; i<4 ; i++ ) {
    fprintf(stdout, "\t%3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d, %3d,\n",
	    mdx->voice[num].ar[i],
	    mdx->voice[num].d1r[i],
	    mdx->voice[num].d2r[i],
	    mdx->voice[num].rr[i],
	    mdx->voice[num].sl[i],
	    mdx->voice[num].tl[i],
	    mdx->voice[num].ks[i],
	    mdx->voice[num].mul[i],
	    mdx->voice[num].dt1[i],
	    mdx->voice[num].dt2[i],
	    mdx->voice[num].ame[i] );
  }
  fprintf(stdout, "#\tCON   FL   SM\n");
  fprintf(stdout, "\t%3d, %3d, %3d )\n",
	  mdx->voice[num].con,
	  mdx->voice[num].fl,
	  mdx->voice[num].slot_mask );
  
  fprintf(stdout, "[ F0 7D 10 %02X ", num);
  sum = mdx->voice[num].v0;
  for ( i=0 ; i<4 ; i++ ) {
    fprintf(stdout, "%02X %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X ",
	    mdx->voice[num].ar[i],
	    mdx->voice[num].d1r[i],
	    mdx->voice[num].d2r[i],
	    mdx->voice[num].rr[i],
	    mdx->voice[num].sl[i],
	    mdx->voice[num].tl[i],
	    mdx->voice[num].ks[i],
	    mdx->voice[num].mul[i],
	    mdx->voice[num].dt1[i],
	    mdx->voice[num].dt2[i],
	    mdx->voice[num].ame[i] );
    sum += mdx->voice[num].v1[i] + mdx->voice[num].v2[i] + mdx->voice[num].v3[i] + mdx->voice[num].v4[i] + mdx->voice[num].v5[i] + mdx->voice[num].v6[i];
  }
  fprintf(stdout, "%02X %02X %02X ",
	  mdx->voice[num].con,
	  mdx->voice[num].fl,
	  mdx->voice[num].slot_mask );
  
  fprintf(stdout, "%02X F7 ]\n", 0x80-(sum%0x7f));
  fprintf(stdout, "\n");
}
#endif

int mdx_get_voice_parameter( MDX_DATA *mdx ) {

  int i;
  int ptr;
  int num;
  unsigned char *buf;

  ptr = mdx->voice_data_offset;
  buf = mdx->data;

  while ( ptr < mdx->length ) {

    if ( mdx->length-ptr < 27 ) break;

    num = buf[ptr++];
    if ( num >= MDX_MAX_VOICE_NUMBER ) return 1;

    mdx->voice[num].v0 = buf[ptr];

    mdx->voice[num].con = buf[ptr  ]&0x07;
    mdx->voice[num].fl  = (buf[ptr++] >> 3)&0x07;
    mdx->voice[num].slot_mask = buf[ptr++];

    /* DT1 & MUL */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v1[i] = buf[ptr];

      mdx->voice[num].mul[i] = buf[ptr] & 0x0f;
      mdx->voice[num].dt1[i] = (buf[ptr] >> 4)&0x07;
      ptr++;
    }
    /* TL */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v2[i] = buf[ptr];

      mdx->voice[num].tl[i] = buf[ptr];
      ptr++;
    }
    /* KS & AR */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v3[i] = buf[ptr];

      mdx->voice[num].ar[i] = buf[ptr] & 0x1f;
      mdx->voice[num].ks[i] = (buf[ptr] >> 6)&0x03;
      ptr++;
    }
    /* AME & D1R */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v4[i] = buf[ptr];

      mdx->voice[num].d1r[i] = buf[ptr] & 0x1f;
      mdx->voice[num].ame[i] = (buf[ptr] >> 7)&0x01;
      ptr++;
    }
    /* DT2 & D2R */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v5[i] = buf[ptr];

      mdx->voice[num].d2r[i] = buf[ptr] & 0x1f;
      mdx->voice[num].dt2[i] = (buf[ptr] >> 6)&0x03;
      ptr++;
    }
    /* SL & RR */
    for ( i=0 ; i<4 ; i++ ) {
      mdx->voice[num].v6[i] = buf[ptr];

      mdx->voice[num].rr[i] = buf[ptr] & 0x0f;
      mdx->voice[num].sl[i] = (buf[ptr] >> 4)&0x0f;
      ptr++;
    }

    /* if ( mdx->dump_voice == FLAG_TRUE ) {
       dump_voices(mdx, num);
    } */
  }

  return 0;
}

/* ------------------------------------------------------------------ */

int mdx_output_titles( MDX_DATA *mdx ) {

  // unsigned char *message;

  return 0;
}
