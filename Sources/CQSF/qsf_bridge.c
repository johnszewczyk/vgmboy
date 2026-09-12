#include "vgmboy_qsf_bridge.h"
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ao.h"
#undef fopen

extern int32 qsf_start(uint8*, uint32); extern int32 qsf_stop(void); extern int32 qsf_sample(stereo_sample_t*);
extern uint8 qsf_memory_read(uint16); extern uint8 qsf_memory_readop(uint16); extern uint8 qsf_memory_readport(uint16);
extern void qsf_memory_write(uint16, uint8); extern void qsf_memory_writeport(uint16, uint8);
volatile ao_bool ao_song_done = 0; static char source_directory[PATH_MAX];
uint8 memory_read(uint16 a){return qsf_memory_read(a);} uint8 memory_readop(uint16 a){return qsf_memory_readop(a);}
uint8 memory_readport(uint16 a){return qsf_memory_readport(a);} void memory_write(uint16 a,uint8 b){qsf_memory_write(a,b);}
void memory_writeport(uint16 a,uint8 b){qsf_memory_writeport(a,b);}
FILE* ao_fopen(const char*p,const char*m){return fopen(p,m);} int ao_mkdir(const char*p){(void)p;return -1;} void ao_sleep(unsigned int m){(void)m;}

int ao_get_lib(const char *filename,uint8 **buffer,uint64 *length){
    char path[PATH_MAX]; snprintf(path,sizeof(path),"%s/%s",source_directory,filename); FILE*f=fopen(path,"rb"); if(!f)return AO_FAIL;
    fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); if(n<=0){fclose(f);return AO_FAIL;} uint8*d=malloc((size_t)n);
    if(!d||fread(d,1,(size_t)n,f)!=(size_t)n){free(d);fclose(f);return AO_FAIL;} fclose(f);*buffer=d;*length=(uint64)n;return AO_SUCCESS;
}

typedef struct {uint8*data;uint32 length;char path[PATH_MAX];int64_t played,play,fade;char title[256],game[256],artist[256],comment[512];} qsf_handle;
static int64_t parse_time(const char*v){if(!v||!*v)return 0;double s=0;int m=0;if(sscanf(v,"%d:%lf",&m,&s)==2)s+=m*60.0;else s=atof(v);return s>0?(int64_t)(s*44100.0):0;}
static void read_tags(qsf_handle*h){
    if(h->length<16)return;uint32 r=h->data[4]|h->data[5]<<8|h->data[6]<<16|h->data[7]<<24,c=h->data[8]|h->data[9]<<8|h->data[10]<<16|h->data[11]<<24;uint64 o=16ULL+r+c;
    if(o+5>h->length||memcmp(h->data+o,"[TAG]",5)!=0)return;size_t n=(size_t)(h->length-o-5);char*tags=malloc(n+1);if(!tags)return;memcpy(tags,h->data+o+5,n);tags[n]=0;
    char*line=tags;char*end0=tags+n;while(line<end0){char*end=strchr(line,'\n');if(!end)end=end0;char*eq=memchr(line,'=',(size_t)(end-line));if(eq){*eq=0;char*v=eq+1;while(*v==' '||*v=='\t')v++;*end=0;
        if(!strcasecmp(line,"title"))snprintf(h->title,sizeof(h->title),"%s",v);else if(!strcasecmp(line,"game"))snprintf(h->game,sizeof(h->game),"%s",v);
        else if(!strcasecmp(line,"artist"))snprintf(h->artist,sizeof(h->artist),"%s",v);else if(!strcasecmp(line,"comment"))snprintf(h->comment,sizeof(h->comment),"%s",v);
        else if(!strcasecmp(line,"length"))h->play=parse_time(v);else if(!strcasecmp(line,"fade"))h->fade=parse_time(v);}
        if(end>=end0)break;line=end+1;
    }free(tags);
}
static int load(qsf_handle*h){FILE*f=fopen(h->path,"rb");if(!f)return 0;fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);if(n<=0||n>UINT32_MAX){fclose(f);return 0;}h->data=malloc((size_t)n);if(!h->data||fread(h->data,1,(size_t)n,f)!=(size_t)n){fclose(f);return 0;}fclose(f);h->length=(uint32)n;read_tags(h);ao_song_done=0;return qsf_start(h->data,h->length)==AO_SUCCESS;}
void* vgmboy_qsf_open(const char*p){if(!p)return NULL;qsf_handle*h=calloc(1,sizeof(*h));if(!h)return NULL;snprintf(h->path,sizeof(h->path),"%s",p);const char*s=strrchr(p,'/');if(s){size_t n=(size_t)(s-p);if(n>=sizeof(source_directory)){free(h);return NULL;}memcpy(source_directory,p,n);source_directory[n]=0;}else strcpy(source_directory,".");if(!load(h)){free(h->data);free(h);return NULL;}return h;}
void vgmboy_qsf_close(void*o){if(o){qsf_stop();qsf_handle*h=o;free(h->data);free(h);}}
int32_t vgmboy_qsf_read(void*o,int16_t*out,int32_t n){qsf_handle*h=o;if(!h||!out||n<=0)return 0;int32_t k=0;for(;k<n;k++){stereo_sample_t s;if(qsf_sample(&s)!=AO_SUCCESS)break;out[k*2]=s.l;out[k*2+1]=s.r;h->played++;if(h->play&&h->played>=h->play+h->fade){ao_song_done=1;break;}}return k;}
int32_t vgmboy_qsf_seek(void*o,int64_t frame){qsf_handle*h=o;if(!h||frame<0)return 0;qsf_stop();free(h->data);h->data=NULL;h->length=0;h->played=0;if(!load(h))return 0;int16_t b[2048];while(h->played+1024<=frame){if(!vgmboy_qsf_read(h,b,1024))return 0;}int64_t left=frame-h->played;if(left){int16_t*x=malloc((size_t)left*2*sizeof(int16_t));if(!x)return 0;vgmboy_qsf_read(h,x,(int32_t)left);free(x);}return 1;}
int32_t vgmboy_qsf_finished(void*o){return !o||ao_song_done;}int64_t vgmboy_qsf_played_frames(void*o){qsf_handle*h=o;return h?h->played:0;}
int64_t vgmboy_qsf_play_length_frames(void*o){qsf_handle*h=o;return h?h->play:0;}int64_t vgmboy_qsf_fade_length_frames(void*o){qsf_handle*h=o;return h?h->fade:0;}
void vgmboy_qsf_configure(void*o,int32_t playMilliseconds,int32_t fadeMilliseconds){qsf_handle*h=o;if(!h)return;h->play=playMilliseconds>0?(int64_t)playMilliseconds*44100/1000:0;h->fade=fadeMilliseconds>0?(int64_t)fadeMilliseconds*44100/1000:0;ao_song_done=0;}
const char* vgmboy_qsf_tag(void*o,const char*n){qsf_handle*h=o;if(!h||!n)return "";if(!strcasecmp(n,"title"))return h->title;if(!strcasecmp(n,"game"))return h->game;if(!strcasecmp(n,"artist"))return h->artist;if(!strcasecmp(n,"comment"))return h->comment;return "";}
const char* vgmboy_qsf_system_name(void*o){(void)o;return "Capcom QSound";}
