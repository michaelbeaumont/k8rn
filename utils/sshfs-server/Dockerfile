FROM docker.io/library/alpine:3.23.3@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

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
