resource "helm_release" "cilium" {
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  name       = "cilium"
  namespace  = "kube-system"

  values = [
    <<-EOT
    ipam:
      mode: kubernetes
    routingMode: native
    ipv4NativeRoutingCIDR: "${var.pod_cidr.ipv4}"
    ipv6:
      enabled: false # TODO when mayastor
    kubeProxyReplacement: true
    envoy:
      baseID: 4244
    hubble:
      relay:
        enabled: true
      ui:
        enabled: true
    securityContext:
      capabilities:
        ciliumAgent:
        # Use to set socket permission
        - CHOWN
        # Used to terminate envoy child process
        - KILL
        # Used since cilium modifies routing tables, etc...
        - NET_ADMIN
        # Used since cilium creates raw sockets, etc...
        - NET_RAW
        # Used since cilium monitor uses mmap
        - IPC_LOCK
        # Needed to switch network namespaces (used for health endpoint, socket-LB).
        # We need it for now but might not need it for >= 5.11 specially
        # for the 'SYS_RESOURCE'.
        # In >= 5.8 there's already BPF and PERMON capabilities
        - SYS_ADMIN
        # Could be an alternative for the SYS_ADMIN for the RLIMIT_NPROC
        - SYS_RESOURCE
        # Both PERFMON and BPF requires kernel 5.8, container runtime
        # cri-o >= v1.22.0 or containerd >= v1.5.0.
        # If available, SYS_ADMIN can be removed.
        #- PERFMON
        #- BPF
        # Allow discretionary access control (e.g. required for package installation)
        - DAC_OVERRIDE
        # Allow to set Access Control Lists (ACLs) on arbitrary files (e.g. required for package installation)
        - FOWNER
        # Allow to execute program that changes GID (e.g. required for package installation)
        - SETGID
        # Allow to execute program that changes UID (e.g. required for package installation)
        - SETUID
        cleanCiliumState:
        # Most of the capabilities here are the same ones used in the
        # cilium-agent's container because this container can be used to
        # uninstall all Cilium resources, and therefore it is likely that
        # will need the same capabilities.
        # Used since cilium modifies routing tables, etc...
        - NET_ADMIN
        # We need it for now but might not need it for >= 5.11 specially
        # for the 'SYS_RESOURCE'.
        # In >= 5.8 there's already BPF and PERMON capabilities
        - SYS_ADMIN
        # Could be an alternative for the SYS_ADMIN for the RLIMIT_NPROC
        - SYS_RESOURCE
        # Both PERFMON and BPF requires kernel 5.8, container runtime
        # cri-o >= v1.22.0 or containerd >= v1.5.0.
        # If available, SYS_ADMIN can be removed.
        #- PERFMON
        #- BPF
    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup
    k8sServiceHost: localhost
    k8sServicePort: 7445
    EOT
  ]
}


