#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ao.h"
#include "corlett.h"
#include "eng_qsf/qsound.h"
#include "eng_qsf/z80.h"

#undef fopen

extern int32 qsf_start(uint8 *buffer, uint32 length);
extern int32 qsf_stop(void);
extern int32 qsf_sample(stereo_sample_t *sample);
extern int32 qsf_fill_info(ao_display_info *info);
extern uint8 qsf_memory_read(uint16 addr);
extern uint8 qsf_memory_readop(uint16 addr);
extern uint8 qsf_memory_readport(uint16 addr);
extern void qsf_memory_write(uint16 addr, uint8 byte);
extern void qsf_memory_writeport(uint16 addr, uint8 byte);

volatile ao_bool ao_song_done = 0;
static char source_directory[PATH_MAX];

uint8 memory_read(uint16 addr) { return qsf_memory_read(addr); }
uint8 memory_readop(uint16 addr) { return qsf_memory_readop(addr); }
uint8 memory_readport(uint16 addr) { return qsf_memory_readport(addr); }
void memory_write(uint16 addr, uint8 byte) { qsf_memory_write(addr, byte); }
void memory_writeport(uint16 addr, uint8 byte) { qsf_memory_writeport(addr, byte); }

FILE *ao_fopen(const char *path, const char *mode) { return fopen(path, mode); }
int ao_mkdir(const char *path) { (void)path; return -1; }
void ao_sleep(unsigned int milliseconds) { (void)milliseconds; }

int ao_get_lib(const char *filename, uint8 **buffer, uint64 *length) {
    char path[PATH_MAX];
    snprintf(path, sizeof(path), "%s/%s", source_directory, filename);
    FILE *file = fopen(path, "rb");
    if (!file) return AO_FAIL;
    if (fseek(file, 0, SEEK_END) != 0) { fclose(file); return AO_FAIL; }
    long size = ftell(file);
    if (size <= 0 || fseek(file, 0, SEEK_SET) != 0) { fclose(file); return AO_FAIL; }
    uint8 *data = malloc((size_t)size);
    if (!data || fread(data, 1, (size_t)size, file) != (size_t)size) {
        free(data); fclose(file); return AO_FAIL;
    }
    fclose(file);
    *buffer = data;
    *length = (uint64)size;
    return AO_SUCCESS;
}

static int read_file(const char *path, uint8 **data, uint32 *length) {
    FILE *file = fopen(path, "rb");
    if (!file) return 0;
    if (fseek(file, 0, SEEK_END) != 0) { fclose(file); return 0; }
    long size = ftell(file);
    if (size <= 0 || (unsigned long)size > UINT32_MAX || fseek(file, 0, SEEK_SET) != 0) {
        fclose(file); return 0;
    }
    *data = malloc((size_t)size);
    if (!*data || fread(*data, 1, (size_t)size, file) != (size_t)size) {
        free(*data); *data = NULL; fclose(file); return 0;
    }
    fclose(file); *length = (uint32)size; return 1;
}

static void json_string(const char *value) {
    putchar('"');
    for (const unsigned char *p = (const unsigned char *)(value ? value : ""); *p; p++) {
        if (*p == '"' || *p == '\\') printf("\\%c", *p);
        else if (*p == '\n') printf("\\n");
        else if (*p == '\r') printf("\\r");
        else if (*p == '\t') printf("\\t");
        else if (*p >= 0x20) putchar(*p);
    }
    putchar('"');
}

int main(int argc, char **argv) {
    if (argc != 2) { fprintf(stderr, "usage: vgmboy-qsf-inspect <file>\n"); return 2; }
    const char *path = argv[1];
    const char *slash = strrchr(path, '/');
    if (slash) {
        size_t length = (size_t)(slash - path);
        if (length >= sizeof(source_directory)) return 2;
        memcpy(source_directory, path, length); source_directory[length] = 0;
    } else strcpy(source_directory, ".");

    uint8 *data = NULL; uint32 length = 0;
    if (!read_file(path, &data, &length) || length < 4 || memcmp(data, "PSF", 3) != 0 || data[3] != 0x41) {
        fprintf(stderr, "not a valid QSF file\n"); free(data); return 1;
    }
    if (qsf_start(data, length) != AO_SUCCESS) {
        fprintf(stderr, "QSF engine rejected the file or its qsflib dependency\n");
        free(data); return 1;
    }
    ao_display_info info = {0};
    qsf_fill_info(&info);
    printf("{\"title\":"); json_string(info.info[1]);
    printf(",\"game\":"); json_string(info.info[2]);
    printf(",\"system\":\"Capcom QSound\",\"artist\":"); json_string(info.info[3]);
    printf(",\"comment\":\"\",\"introLengthMs\":0,\"loopLengthMs\":0,\"playLengthMs\":0,\"fadeLengthMs\":0,\"trackCount\":1}\n");
    qsf_stop(); free(data); return 0;
}
