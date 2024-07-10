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
- SSH key for flux
  - Must be a deploy key for this repo
- Age key for SOPS-encrypted data with flux
- A KMS service for talos, I'm using [talos-unlockr](https://github.com/michaelbeaumont/talos-unlockr) to easily unlock things on demand.

The cluster nodes have to be assigned IPs reachable from your machine.

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

This Terraform assumes Tailscale IPs known in advance.
Otherwise there's a large delay between when the nodes start querying the API
endpoint/we try to contact the API endpoint and when the DNS records are propagated.

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

We set the Terraform variable `tailscale_node_ips = ["100.64.1.10", "100.64.1.11", "100.64.1.12"]`.

## Kubernetes

### Intel GPU plugin

My nodes are Beelink EQ12s, their N100 CPU is a 12th generation Intel,
so it has Intel Quick Sync Video support for hardware acceleration with Jellyfin.

This repo uses
[Intel's GPU plugin](https://github.com/intel/intel-device-plugins-for-kubernetes/blob/main/cmd/gpu_plugin/README.md)
to [make everything available to the Jellyfin `Pods`](./k8s/base/gpu).
