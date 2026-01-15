FROM docker.io/library/alpine:3.23.2@sha256:865b95f46d98cf867a156fe4a135ad3fe50d2056aa3f25ed31662dff6da4eb62

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN apk add --no-cache zfs=2.4.0-r0 bash

COPY --chmod=755 scrub-and-status.sh /usr/local/bin/scrub-and-status.sh
ENTRYPOINT ["/usr/local/bin/scrub-and-status.sh"]
