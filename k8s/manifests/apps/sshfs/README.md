# `sshfs`

Note that this tunnels SSH through TLS for SNI routing:

In `~/.ssh/config`:

```
Host *.sshfs.<suffix>
  ProxyCommand openssl s_client -quiet -verify_quiet -connect %h:%p -servername %h
```
