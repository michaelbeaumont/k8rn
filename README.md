# k8rn

This holds everything for my bare metal Talos k8s cluster.

The cluster is initialized with Terraform, including flux, which then runs off of this repo.

## Setup

This configuration depends on:

- Tailscale
  - In particular an oauth client that is tagged to own the tags assigned to each device in
    [the tailscale Terraform](./infra/tailscale.tf)
- Cloudflare
  - A DNS zone to assign a subdomain in
- A KMS service for talos, I'm using [talos-unlockr](https://github.com/michaelbeaumont/talos-unlockr) to easily unlock things on demand.
- SSH key for flux
  - Must be a deploy key for this repo
- Age key for SOPS-encrypted data with flux
- An OIDC IdP for cluster authzn

The cluster nodes have to be assigned IPs reachable from your machine.

### Install

#### Talos images

Each image:

- gets a UUID in the META partition because the mini PCs I have don't have proper UUIDs generated
- has `stable_secret` set as a kernel param

Creating the image factory config and fetching each image is handled in
Terraform and exposed as outputs. The `justfile` makes it easy to grab the
update image and the ISOs.

Each node is added to the Terraform variable `nodes` before it's added to either
`control_plane_nodes` or `worker_nodes`.

### DNS

This Terraform uses Cloudflare to assign a public DNS name to load balance
between the Tailscale IPs.

Another option would be to run a something like
[coredns-tailscale](https://github.com/damomurf/coredns-tailscale) to handle
this.

This has two problems:

- [Talos can't take advantage of split DNS yet](https://github.com/siderolabs/talos/issues/7287)
  so it can't reach itself.
- It's another piece of infrastructure that has to be running "somewhere"

### Tailscale

This terraform can use IPv6 addresses, which Tailscale provisions dynamically.

Depending on which DNS you're using, note that there might be a
large delay between when the nodes start querying the API endpoint
/we try to contact the API endpoint and when the DNS records are propagated.

Somewhat out of scope but for ease of use I also assign IPv4 Tailscale addresses
statically.
Assuming `cluster_name = "k8rn"`, this can be achieved via ACLs:

```json
    "nodeAttrs": [
        {
            "target": ["tag:k8rn-cp-0"],
            "ipPool": ["100.64.1.10/32"],
        },
        {
            "target": ["tag:k8rn-cp-1"],
            "ipPool": ["100.64.1.11/32"],
        },
        {
            "target": ["tag:k8rn-cp-2"],
            "ipPool": ["100.64.1.12/32"],
        },
    ],
```

Each node is assigned `tag:<node hostname>` which Tailscale then uses to assign an IP pool,
in this case a pool of size one.

## Kubernetes

### Cilium

Cilium is set up with native routing. This is a bit tricky with Tailscale
because each node needs to advertise routes for its `podCIDRs` but we can't
directly put this in the `ExtensionServiceConfig` since it isn't known when
we initialize the extension.

Instead, two extra init containers run with the cilium agent.
The first retrieves the node's `podCIDRs` and the second calls
`tailscale set --advertise-routes` with those `podCIDRs`.
The Tailscale extension is configured with `--accept-routes`
and `--snat-subnet-routes=false`,
since we don't want or need to SNAT between Pods on different nodes.

Ideally this functionality would be upstreamed but for now, this just works.

This requires some ACLs set up in Tailscale:

```json
{
    "ipsets": {
        "ipset:k8rn-pods": [
            "add 10.244.0.0/16",
        ],
    },
    "autoApprovers": {
        "routes": {
            "10.244.0.0/16": [ // can't use ipset here
                "tag:k8rn-node",
            ],
        },
    },
    "acls": {
        ...
        // k8rn: nodes and pods can reach each other
        {
            "action": "accept",
            "src":    ["tag:k8rn-node", "ipset:k8rn-pods"],
            "dst": [
                "tag:k8rn-node:*",
                "ipset:k8rn-pods:*",
            ],
        },
    },
}
```

### Intel GPU plugin

My nodes are Beelink EQ12s, their N100 CPU is a 12th generation Intel,
so it has Intel Quick Sync Video support for hardware acceleration with Jellyfin.

This repo uses
[Intel's GPU plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/cmd/gpu_plugin/README.md)
to [make everything available to the Jellyfin `Pods`](./k8s/base/gpu).

### Envoy gateway

k8rn is running Envoy gateway with a relatively complicated architecture.

Ideally we'd use the Tailscale operator to expose the gateway as a `LoadBalancer` `Service`
and the `Gateway` would get its own Tailscale machine.
However due to tailscale/tailscale#12393 this is currently infeasible.

Instead we rely on the nodes being Tailscale machines:

- Set `net.ipv4.ip_unprivileged_port_start=0` on the nodes so we can listen on `443` without root
- The Envoy gateway `Pods` run with `hostNetwork: true`
- Set `useListenerPortAsContainerPort: true` so the container really listens on `443`
- An `EnvoyPatchPolicy` modifies the listener to bind only to `tailscale0` with `SO_BINDTODEVICE`
- The Service is configured as `NodePort` so that `external-dns` creates A/AAAA records pointing to each of the node IPs.
  - Note this depends on clients failing over between DNS records because only one of the nodes will
    have Envoy gateway running. But this seems to work from my testing
  - Otherwise Envoy can be deployed as a `DaemonSet`

### External services

Some services are running on a different server in the tailnet and a `Service`
with a manually managed `EndpointSlice` handles forwarding the traffic.

### OIDC

This sets up Talos to authenticate using OIDC.

In my case with Pocket ID + PKCE + wanting to use the `k8rn_admin` group for `cluster-admin`
and eventually take advantage of `preferred_username`,
I had to setup the `kubectl` `oidc-login` plugin as follows:

```
kubectl oidc-login setup \
        --oidc-issuer-url=${MY_ISSUER} \
        --oidc-client-id=${MY_CALLBACK} \
        --oidc-pkce-method S256 \
        --oidc-extra-scope profile \
        --oidc-extra-scope groups
```

> [!IMPORTANT]
> Replace this with `AuthenticationConfiguration` when Talos supports it
