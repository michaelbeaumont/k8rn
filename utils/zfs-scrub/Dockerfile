FROM docker.io/library/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

RUN apk add --no-cache zfs=2.4.0-r0 bash

COPY --chmod=755 scrub-and-status.sh /usr/local/bin/scrub-and-status.sh
ENTRYPOINT ["/usr/local/bin/scrub-and-status.sh"]
