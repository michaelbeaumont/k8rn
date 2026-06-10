FROM docker.io/library/alpine:3.24.0@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

RUN \
  apk add --no-cache --upgrade \
    openssh-server-pam && \
  rm -rf \
    /tmp/* \
    $HOME/.cache

# Setup a non-root user without a password
RUN echo "user:*:1000:1000::/home/user:/bin/sh" >> /etc/passwd
RUN mkdir /home/user && chown 1000:1000 /home/user

LABEL org.opencontainers.image.source="https://github.com/michaelbeaumont/k8rn"

EXPOSE 22
ENTRYPOINT ["/usr/sbin/sshd.pam", "-D", "-e"]
