FROM --platform=$BUILDPLATFORM alpine:latest AS builder
ARG TARGET_PLATFORM=linux
ARG TARGET_ARCH=arm64
ARG ALPINE_VER=3.23.4
ARG ALPINE_ARCH=aarch64
ARG XRAY_VER=26.3.27
ARG XRAY_ARCH=arm64-v8a
ARG TUN_VER=2.14.4
ARG TUN_ARCH=arm64

WORKDIR /build
RUN apk add --no-cache curl unzip gzip tar && \
    curl -sL https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VER}-${ALPINE_ARCH}.tar.gz -o alpine.tar.gz && \
    mkdir rootfs && tar -xzf alpine.tar.gz -C rootfs && \
    apk add --no-cache --root /build/rootfs --initdb --arch ${ALPINE_ARCH} --no-scripts \
        tzdata iproute2 ca-certificates && \
    curl -sL https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VER}/Xray-${TARGET_PLATFORM}-${XRAY_ARCH}.zip -o xray.zip && \
    unzip -oj xray.zip xray -d ./rootfs/opt && \
    curl -sL https://github.com/heiher/hev-socks5-tunnel/releases/download/${TUN_VER}/hev-socks5-tunnel-${TARGET_PLATFORM}-${TUN_ARCH} -o ./rootfs/opt/hev-socks5-tunnel && \
    chmod +x ./rootfs/opt/hev-socks5-tunnel && \
    mkdir -p ./rootfs/etc/xray ./rootfs/usr/local/share/xray
COPY ./start.sh ./rootfs/opt/start.sh


FROM --platform=${TARGET_PLATFORM}/${TARGET_ARCH} scratch
COPY --from=builder /build/rootfs/ /
ENV SOCKS5_PORT=1080
WORKDIR /opt
ENTRYPOINT ["/bin/sh", "/opt/start.sh"]
