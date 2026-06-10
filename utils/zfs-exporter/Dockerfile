FROM docker.io/library/alpine:3.24.0@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4
ARG ZFS_EXPORTER_VERSION=2.3.12

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN echo "@edge https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

RUN apk add --no-cache zfs@edge=2.4.2-r0 zfs-libs@edge=2.4.2-r0 bash

WORKDIR /usr/local/bin
RUN wget -qO- https://github.com/pdf/zfs_exporter/releases/download/v$ZFS_EXPORTER_VERSION/zfs_exporter-$ZFS_EXPORTER_VERSION.linux-amd64.tar.gz | tar zvfx - --strip-components=1 zfs_exporter-$ZFS_EXPORTER_VERSION.linux-amd64/zfs_exporter

ENTRYPOINT ["/usr/local/bin/zfs_exporter"]
