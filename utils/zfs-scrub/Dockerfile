FROM docker.io/library/alpine:3.24.0@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN echo "@edge https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

RUN apk add --no-cache zfs@edge=2.4.2-r0 zfs-libs@edge=2.4.2-r0 bash

COPY --chmod=755 scrub-and-status.sh /usr/local/bin/scrub-and-status.sh
ENTRYPOINT ["/usr/local/bin/scrub-and-status.sh"]
