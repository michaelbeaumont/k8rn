FROM docker.io/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
ARG ZFS_EXPORTER_VERSION=2.3.12

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN apk add --no-cache zfs=2.4.1-r0 bash

WORKDIR /usr/local/bin
RUN wget -qO- https://github.com/pdf/zfs_exporter/releases/download/v$ZFS_EXPORTER_VERSION/zfs_exporter-$ZFS_EXPORTER_VERSION.linux-amd64.tar.gz | tar zvfx - --strip-components=1 zfs_exporter-$ZFS_EXPORTER_VERSION.linux-amd64/zfs_exporter

ENTRYPOINT ["/usr/local/bin/zfs_exporter"]
