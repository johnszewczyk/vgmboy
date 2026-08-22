#include "vgmboy_ffmpeg.h"

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/mem.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct vgmboy_ffmpeg_decoder {
    AVFormatContext *format;
    AVCodecContext *codec;
    SwrContext *resampler;
    AVPacket *packet;
    AVFrame *frame;
    int stream_index;
    int output_rate;
    float *pending;
    int pending_frames;
    int pending_index;
    int input_eof;
    int flush_sent;
    int output_eof;
};

static void set_error(char **target, const char *prefix, int code) {
    if (!target) return;
    char text[AV_ERROR_MAX_STRING_SIZE] = {0};
    av_strerror(code, text, sizeof(text));
    size_t length = strlen(prefix) + strlen(text) + 3;
    *target = av_malloc(length);
    if (*target) snprintf(*target, length, "%s: %s", prefix, text);
}

static void reset_pending(vgmboy_ffmpeg_decoder *decoder) {
    av_freep(&decoder->pending);
    decoder->pending_frames = 0;
    decoder->pending_index = 0;
}

static int prepare_pending(vgmboy_ffmpeg_decoder *decoder, AVFrame *frame, char **error_message) {
    int max_frames = (int)av_rescale_rnd(
        swr_get_delay(decoder->resampler, decoder->codec->sample_rate) + frame->nb_samples,
        decoder->output_rate,
        decoder->codec->sample_rate,
        AV_ROUND_UP
    );
    if (max_frames < 1) return 0;
    float *converted = av_malloc_array((size_t)max_frames, sizeof(float) * 2);
    if (!converted) {
        if (error_message) *error_message = av_strdup("FFmpeg output allocation failed.");
        return AVERROR(ENOMEM);
    }
    uint8_t *output[] = { (uint8_t *)converted, NULL };
    const int converted_frames = swr_convert(
        decoder->resampler,
        output,
        max_frames,
        (const uint8_t **)frame->extended_data,
        frame->nb_samples
    );
    if (converted_frames < 0) {
        av_free(converted);
        set_error(error_message, "FFmpeg resample failed", converted_frames);
        return converted_frames;
    }
    reset_pending(decoder);
    decoder->pending = converted;
    decoder->pending_frames = converted_frames;
    return 0;
}

static int decode_next_frame(vgmboy_ffmpeg_decoder *decoder, char **error_message) {
    while (1) {
        int result = avcodec_receive_frame(decoder->codec, decoder->frame);
        if (result == 0) {
            result = prepare_pending(decoder, decoder->frame, error_message);
            av_frame_unref(decoder->frame);
            return result;
        }
        if (result == AVERROR_EOF) {
            decoder->output_eof = 1;
            return 0;
        }
        if (result != AVERROR(EAGAIN)) {
            set_error(error_message, "FFmpeg decode failed", result);
            return result;
        }

        if (decoder->input_eof) {
            if (!decoder->flush_sent) {
                result = avcodec_send_packet(decoder->codec, NULL);
                if (result < 0 && result != AVERROR_EOF) {
                    set_error(error_message, "FFmpeg flush failed", result);
                    return result;
                }
                decoder->flush_sent = 1;
                continue;
            }
            decoder->output_eof = 1;
            return 0;
        }

        result = av_read_frame(decoder->format, decoder->packet);
        if (result == AVERROR_EOF) {
            decoder->input_eof = 1;
            continue;
        }
        if (result < 0) {
            set_error(error_message, "FFmpeg input read failed", result);
            return result;
        }
        if (decoder->packet->stream_index != decoder->stream_index) {
            av_packet_unref(decoder->packet);
            continue;
        }
        result = avcodec_send_packet(decoder->codec, decoder->packet);
        av_packet_unref(decoder->packet);
        if (result == AVERROR(EAGAIN)) continue;
        if (result < 0) {
            set_error(error_message, "FFmpeg packet decode failed", result);
            return result;
        }
    }
}

vgmboy_ffmpeg_decoder *vgmboy_ffmpeg_decoder_create(const char *path, int output_rate, char **error_message) {
    if (error_message) *error_message = NULL;
    vgmboy_ffmpeg_decoder *decoder = av_mallocz(sizeof(*decoder));
    if (!decoder) return NULL;
    decoder->output_rate = output_rate > 0 ? output_rate : 44100;
    int result = avformat_open_input(&decoder->format, path, NULL, NULL);
    if (result < 0) { set_error(error_message, "FFmpeg could not open input", result); goto failed; }
    result = avformat_find_stream_info(decoder->format, NULL);
    if (result < 0) { set_error(error_message, "FFmpeg could not inspect input", result); goto failed; }
    decoder->stream_index = av_find_best_stream(decoder->format, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (decoder->stream_index < 0) { set_error(error_message, "FFmpeg could not find audio", decoder->stream_index); goto failed; }
    const AVCodecParameters *parameters = decoder->format->streams[decoder->stream_index]->codecpar;
    const AVCodec *codec = avcodec_find_decoder(parameters->codec_id);
    if (!codec) { if (error_message) *error_message = av_strdup("FFmpeg audio decoder is unavailable."); goto failed; }
    decoder->codec = avcodec_alloc_context3(codec);
    if (!decoder->codec) { if (error_message) *error_message = av_strdup("FFmpeg decoder allocation failed."); goto failed; }
    result = avcodec_parameters_to_context(decoder->codec, parameters);
    if (result < 0) { set_error(error_message, "FFmpeg decoder setup failed", result); goto failed; }
    result = avcodec_open2(decoder->codec, codec, NULL);
    if (result < 0) { set_error(error_message, "FFmpeg decoder open failed", result); goto failed; }
    decoder->resampler = swr_alloc();
    if (!decoder->resampler) { if (error_message) *error_message = av_strdup("FFmpeg resampler allocation failed."); goto failed; }
    AVChannelLayout stereo = AV_CHANNEL_LAYOUT_STEREO;
    result = av_opt_set_chlayout(decoder->resampler, "in_chlayout", &decoder->codec->ch_layout, 0);
    if (result < 0) { set_error(error_message, "FFmpeg input layout failed", result); goto failed; }
    result = av_opt_set_int(decoder->resampler, "in_sample_rate", decoder->codec->sample_rate, 0);
    if (result < 0) { set_error(error_message, "FFmpeg input rate failed", result); goto failed; }
    result = av_opt_set_sample_fmt(decoder->resampler, "in_sample_fmt", decoder->codec->sample_fmt, 0);
    if (result < 0) { set_error(error_message, "FFmpeg input format failed", result); goto failed; }
    result = av_opt_set_chlayout(decoder->resampler, "out_chlayout", &stereo, 0);
    if (result < 0) { set_error(error_message, "FFmpeg output layout failed", result); goto failed; }
    result = av_opt_set_int(decoder->resampler, "out_sample_rate", decoder->output_rate, 0);
    if (result < 0) { set_error(error_message, "FFmpeg output rate failed", result); goto failed; }
    result = av_opt_set_sample_fmt(decoder->resampler, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
    if (result < 0) { set_error(error_message, "FFmpeg output format failed", result); goto failed; }
    result = swr_init(decoder->resampler);
    if (result < 0) { set_error(error_message, "FFmpeg resampler initialization failed", result); goto failed; }
    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (!decoder->packet || !decoder->frame) { if (error_message) *error_message = av_strdup("FFmpeg frame allocation failed."); goto failed; }
    return decoder;
failed:
    vgmboy_ffmpeg_decoder_destroy(decoder);
    return NULL;
}

void vgmboy_ffmpeg_decoder_destroy(vgmboy_ffmpeg_decoder *decoder) {
    if (!decoder) return;
    reset_pending(decoder);
    av_packet_free(&decoder->packet);
    av_frame_free(&decoder->frame);
    swr_free(&decoder->resampler);
    avcodec_free_context(&decoder->codec);
    avformat_close_input(&decoder->format);
    av_free(decoder);
}

int vgmboy_ffmpeg_decoder_start(vgmboy_ffmpeg_decoder *decoder, char **error_message) {
    return vgmboy_ffmpeg_decoder_seek(decoder, 0, error_message);
}

int vgmboy_ffmpeg_decoder_seek(vgmboy_ffmpeg_decoder *decoder, int64_t milliseconds, char **error_message) {
    if (error_message) *error_message = NULL;
    const AVStream *stream = decoder->format->streams[decoder->stream_index];
    const int64_t timestamp = av_rescale_q(milliseconds > 0 ? milliseconds : 0, (AVRational){1, 1000}, stream->time_base);
    int result = av_seek_frame(decoder->format, decoder->stream_index, timestamp, AVSEEK_FLAG_BACKWARD);
    if (result < 0) { set_error(error_message, "FFmpeg seek failed", result); return result; }
    avcodec_flush_buffers(decoder->codec);
    swr_close(decoder->resampler);
    result = swr_init(decoder->resampler);
    if (result < 0) { set_error(error_message, "FFmpeg resampler reset failed", result); return result; }
    reset_pending(decoder);
    decoder->input_eof = 0;
    decoder->flush_sent = 0;
    decoder->output_eof = 0;
    return 0;
}

int vgmboy_ffmpeg_decoder_read(vgmboy_ffmpeg_decoder *decoder, float *left, float *right, int frames, int *frames_read, char **error_message) {
    if (frames_read) *frames_read = 0;
    if (error_message) *error_message = NULL;
    int copied = 0;
    while (copied < frames) {
        if (decoder->pending_index < decoder->pending_frames) {
            const int available = decoder->pending_frames - decoder->pending_index;
            const int count = available < (frames - copied) ? available : (frames - copied);
            for (int index = 0; index < count; index += 1) {
                left[copied + index] = decoder->pending[(decoder->pending_index + index) * 2];
                right[copied + index] = decoder->pending[(decoder->pending_index + index) * 2 + 1];
            }
            copied += count;
            decoder->pending_index += count;
            continue;
        }
        reset_pending(decoder);
        if (decoder->output_eof) break;
        const int result = decode_next_frame(decoder, error_message);
        if (result < 0) return result;
        if (decoder->output_eof && decoder->pending_frames == 0) break;
    }
    if (frames_read) *frames_read = copied;
    return 0;
}

int64_t vgmboy_ffmpeg_decoder_duration_ms(const vgmboy_ffmpeg_decoder *decoder) {
    if (!decoder || decoder->format->duration == AV_NOPTS_VALUE) return 0;
    return av_rescale(decoder->format->duration, 1000, AV_TIME_BASE);
}

void vgmboy_ffmpeg_error_message_free(char *message) { av_free(message); }
