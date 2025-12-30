FROM debian:13 AS debian

RUN cd /tmp
# All packages in the dependency tree of fstrim
RUN apt-get update \
    && apt-get download \
      libblkid1 libmount1 libselinux1 libpcre2-8-0 \
      util-linux \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN for deb in *.deb; do dpkg --extract $deb /tmp/packages; done

FROM gcr.io/distroless/base-nossl-debian13
LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

COPY --from=debian /tmp/packages/usr/lib/x86_64-linux-gnu/ /usr/lib
COPY --from=debian /tmp/packages/usr/sbin/fstrim /usr/sbin/

ENTRYPOINT ["/usr/sbin/fstrim"]
