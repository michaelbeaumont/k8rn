FROM alpine:latest AS downloader
ARG EXTENSION_VERSION

RUN apk add --no-cache curl zip

RUN curl -L https://github.com/nzbgetcom/Extension-VideoSort/releases/download/v${EXTENSION_VERSION}/videosort-${EXTENSION_VERSION}-dist.zip -o /tmp/videosort.zip && mkdir /tmp/videosort && unzip /tmp/videosort.zip -d /tmp/videosort

FROM scratch
LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

COPY --from=downloader /tmp/videosort/VideoSort/* /
