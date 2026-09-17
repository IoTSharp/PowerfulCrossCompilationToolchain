#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|arm>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"
pcct_setup_target "$1"

case "$PCCT_TARGET" in
    x86|arm) ;;
    *) echo "unsupported camera codec verification target: $PCCT_TARGET" >&2; exit 1 ;;
esac

workdir=$(mktemp -d /tmp/pcct-camera-codecs.XXXXXX)
trap 'rm -rf "$workdir"' EXIT INT TERM
test "$("$PKG_CONFIG" --modversion openh264)" = "$OPENH264_VERSION"
test -f "$PCCT_PREFIX/share/licenses/openh264-$OPENH264_VERSION/LICENSE"

# Inspect definitions once; undefined codec references are not capability proof.
"$NM" -g --defined-only "$PCCT_LIBDIR/libavcodec.a" > "$workdir/codec-symbols"
grep -q ' ff_hevc_decoder$' "$workdir/codec-symbols"
grep -q ' ff_hevc_mp4toannexb_bsf$' "$workdir/codec-symbols"
grep -q ' ff_libopenh264_encoder$' "$workdir/codec-symbols"

cat > "$workdir/codec-smoke.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <libavcodec/avcodec.h>
#include <libavcodec/bsf.h>

/* Encode and decode one real frame; discovery alone misses runtime failures. */
int main(void)
{
    const AVCodec *encoder = avcodec_find_encoder_by_name("libopenh264");
    const AVCodec *decoder = avcodec_find_decoder(AV_CODEC_ID_H264);
    AVCodecContext *enc = NULL;
    AVCodecContext *dec = NULL;
    AVFrame *input = av_frame_alloc();
    AVFrame *output = av_frame_alloc();
    AVPacket *packet = av_packet_alloc();
    int result = 1;
    int row;

    if (encoder != NULL && decoder != NULL && input != NULL &&
        output != NULL && packet != NULL &&
        avcodec_find_decoder(AV_CODEC_ID_HEVC) != NULL &&
        av_bsf_get_by_name("hevc_mp4toannexb") != NULL) {
        enc = avcodec_alloc_context3(encoder);
        dec = avcodec_alloc_context3(decoder);
    }
    if (enc != NULL && dec != NULL) {
        enc->width = 64;
        enc->height = 64;
        enc->pix_fmt = AV_PIX_FMT_YUV420P;
        enc->time_base = (AVRational){1, 25};
        enc->framerate = (AVRational){25, 1};
        enc->bit_rate = 128000;
        enc->gop_size = 25;
        enc->max_b_frames = 0;
        enc->thread_count = 1;
        input->width = enc->width;
        input->height = enc->height;
        input->format = enc->pix_fmt;
        input->pts = 0;
        if (avcodec_open2(enc, encoder, NULL) == 0 &&
            avcodec_open2(dec, decoder, NULL) == 0 &&
            av_frame_get_buffer(input, 32) == 0) {
            for (row = 0; row < 64; ++row)
                memset(input->data[0] + row * input->linesize[0], 80, 64);
            for (row = 0; row < 32; ++row) {
                memset(input->data[1] + row * input->linesize[1], 128, 32);
                memset(input->data[2] + row * input->linesize[2], 128, 32);
            }
            if (avcodec_send_frame(enc, input) == 0 &&
                avcodec_receive_packet(enc, packet) == 0 && packet->size > 0 &&
                avcodec_send_packet(dec, packet) == 0 &&
                avcodec_receive_frame(dec, output) == 0 &&
                output->width == 64 && output->height == 64 &&
                output->data[0][0] >= 75 && output->data[0][0] <= 85) {
                result = 0;
                puts("HEVC decoder/BSF and OpenH264 encode/decode smoke passed");
            }
        }
    }
    av_packet_free(&packet);
    av_frame_free(&input);
    av_frame_free(&output);
    avcodec_free_context(&enc);
    avcodec_free_context(&dec);
    return result;
}
EOF

# Both direct FFmpeg consumers and laneCamera's aggregate package must close.
"$CC" -std=gnu99 -o "$workdir/codec-smoke" "$workdir/codec-smoke.c" \
    $("$PKG_CONFIG" --cflags --static --libs libavcodec libavutil)
"$CC" -std=gnu99 -o "$workdir/webrtc-codec-smoke" "$workdir/codec-smoke.c" \
    $("$PKG_CONFIG" --cflags --static --libs laneapp-webrtc)
pcct_assert_target_file "$workdir/codec-smoke"
pcct_assert_target_file "$workdir/webrtc-codec-smoke"

readelf -d "$workdir/codec-smoke" > "$workdir/needed"
readelf -d "$workdir/webrtc-codec-smoke" >> "$workdir/needed"
if grep NEEDED "$workdir/needed" | \
    grep -Eq 'lib(avcodec|avutil|openh264|stdc\+\+|gcc_s)\.so'; then
    echo "camera codec smoke retained a third-party shared dependency" >&2
    exit 1
fi

if [ "$PCCT_TARGET" = "x86" ]; then
    timeout 30 "$workdir/codec-smoke"
    timeout 30 "$workdir/webrtc-codec-smoke"
else
    # Cross linking is not an ARM runtime acceptance test.
    readelf --version-info "$workdir/codec-smoke" > "$workdir/versions"
    if grep -Eq 'GLIBC_2\.(1[4-9]|[2-9][0-9])' "$workdir/versions"; then
        echo "camera codecs exceeded the ARM glibc 2.13 baseline" >&2
        exit 1
    fi
    echo "ARM camera codec symbols, EABI and static link verified; runtime NOT_RUN"
fi
