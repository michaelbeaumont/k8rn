FROM docker.io/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN echo "@edge https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

RUN apk add --no-cache zfs@edge=2.4.2-r0 zfs-libs@edge=2.4.2-r0 bash

COPY --chmod=755 scrub-and-status.sh /usr/local/bin/scrub-and-status.sh
ENTRYPOINT ["/usr/local/bin/scrub-and-status.sh"]
