resource "helm_release" "cilium" {
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  name       = "cilium"
  namespace  = "kube-system"
  version    = "1.17.5"

  values = [
    <<-EOT
    ipam:
      mode: kubernetes
    routingMode: native
    ipv4NativeRoutingCIDR: "${var.pod_cidr.ipv4}"
    ipv6NativeRoutingCIDR: "${var.pod_cidr.ipv6}"
    ipv6:
      enabled: true
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
    extraInitContainers:
      - name: get-node-pod-cidr
        image: bitnami/kubectl:latest
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          seccompProfile:
            type: RuntimeDefault
        command: [sh, -c]
        args:
          - |
            set -e
            kubectl get nodes $(NODE_NAME) -o json > /mnt/share-pod-cidr/node_json
            cat /mnt/share-pod-cidr/node_json | jq -r '.spec.podCIDRs | join(",")' > /mnt/share-pod-cidr/out
        env:
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: KUBERNETES_SERVICE_HOST
            value: "localhost"
          - name: KUBERNETES_SERVICE_PORT
            value: "7445"
        volumeMounts:
          - mountPath: /mnt/share-pod-cidr
            name: share-pod-cidr
      - name: set-tailscale-advertise-routes
        image: tailscale/tailscale:latest
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
          runAsNonRoot: false
          readOnlyRootFilesystem: true
          seccompProfile:
            type: RuntimeDefault
        command: [sh, -c]
        args: ["tailscale set --advertise-routes $(cat /mnt/share-pod-cidr/out)"]
        volumeMounts:
          - mountPath: /var/run/tailscale/tailscaled.sock
            name: tailscaled-socket
          - mountPath: /mnt/share-pod-cidr
            name: share-pod-cidr
    extraVolumes:
      - name: tailscaled-socket
        hostPath:
          path: /var/run/tailscale/tailscaled.sock
      - name: share-pod-cidr
        emptyDir: {}
    EOT
  ]
}
