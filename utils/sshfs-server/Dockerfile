FROM docker.io/library/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11

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
