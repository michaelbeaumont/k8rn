resource "talos_machine_secrets" "this" {
  talos_version = "v1.8.1"
}

resource "random_uuid" "nodes" {
  for_each = toset(keys(var.nodes))
}

resource "talos_image_factory_schematic" "this" {
  for_each = random_uuid.nodes
  schematic = yamlencode(
    {
      customization = {
        meta = [
          {
            key : 15, // 0x0f
            value : each.value.id,
          }
        ]
        extraKernelArgs = [
          "sysctl.net.ipv6.conf.default.stable_secret=${var.stable_secret}",
        ]
        systemExtensions = {
          officialExtensions = compact([
            "siderolabs/i915",
            "siderolabs/intel-ucode",
            "siderolabs/nfsd",
            "siderolabs/tailscale",
            "siderolabs/zfs",
            contains(var.nodes[each.key].tags, "qemu") ? "siderolabs/qemu-guest-agent" : "",
          ])
        }
      }
    }
  )
}

data "talos_image_factory_urls" "this" {
  for_each      = talos_image_factory_schematic.this
  talos_version = var.talos_version
  schematic_id  = each.value.id
  platform      = "metal"
}

locals {
  image_uri = {
    for node, schematic in talos_image_factory_schematic.this
    : node => "factory.talos.dev/installer-secureboot/${schematic.id}:${var.talos_version}"
  }
  tailscale_cidrs = [
    "100.64.0.0/10",
    "fd7a:115c:a1e0::/64",
  ]
}

locals {
  // shared between both but we can't get rid of the each references
  common_patches_by_node = {
    for name, node in var.nodes
    : name => [
      templatefile(
        "${path.module}/files/base.yaml.tmpl",
        {
          image_uri                 = local.image_uri[name]
          dns_loadbalancer_hostname = local.dns_loadbalancer_hostname
          hostname                  = local.hostnames[name]
          tailscale_fqdn            = "${local.hostnames[name]}.${var.tailnet_name}"
          install_disk              = node.install_disk
          cluster_endpoint_host     = local.dns_loadbalancer_hostname
          pod_subnets               = var.pod_subnets
          service_subnets           = var.service_subnets
        }
      ),
      templatefile("${path.module}/files/tailscale.yaml.tmpl", {
        tailscale_key = contains(keys(local.control_plane_nodes), name) ? tailscale_tailnet_key.unsigned-cp[name].key : tailscale_tailnet_key.unsigned-worker[name].key
      }),
      templatefile("${path.module}/files/encrypt-kms.patch.yaml.tmpl", {
        kms_endpoint = var.kms_endpoint
      }),
      file("${path.module}/files/openebs.patch.yaml"),
      templatefile("${path.module}/files/hubble-peer-rules.yaml.tmpl", {
        pod_subnets = var.pod_subnets,
        node_ips    = local.tailscale_cidrs,
      }),
      templatefile("${path.module}/files/cilium-health.yaml.tmpl", {
        node_ips = local.tailscale_cidrs,
      }),
      file("${path.module}/files/services-ingress.yaml"),
      !contains(node.tags, "qemu") ? [
        file("${path.module}/files/watchdog.yaml")
      ] : [],
      templatefile("${path.module}/files/mayastor-rules.yaml.tmpl", {
        node_ips    = local.tailscale_cidrs,
        pod_subnets = var.pod_subnets,
      }),
      contains(var.mayastor_io_engine_nodes, name) ? [
        file("${path.module}/files/mayastor.patch.yaml"),
        templatefile("${path.module}/files/mayastor-io-engine-rules.yaml.tmpl", {
          node_ips    = local.tailscale_cidrs,
          pod_subnets = var.pod_subnets,
        }),
        file("${path.module}/files/mayastor-io-node-ephemeral-config.yaml"),
      ] : [],
      templatefile("${path.module}/files/metallb-rules.yaml.tmpl", {
        node_ips = local.tailscale_cidrs,
      }),
      templatefile("${path.module}/files/metrics-network-rules.yaml.tmpl", {
        node_ips    = local.tailscale_cidrs,
        pod_subnets = var.pod_subnets,
      }),
      [for device in node.network_devices : templatefile("${path.module}/files/eth-tailscale-optimizations.yaml.tmpl", {
        device = device
      })],
      contains(node.tags, "qemu") ? [
        file("${path.module}/files/qemu-exclusive-taints.yaml"),
      ] : [],
      file("${path.module}/files/kubelet-rotate-server-crts.yaml"),
      file("${path.module}/files/zfs.yaml"),
      file("${path.module}/files/nfs.yaml"),
    ] if contains(keys(merge(local.control_plane_nodes, local.worker_nodes)), name)
  }
}

data "talos_machine_configuration" "control_plane_nodes" {
  for_each         = local.control_plane_nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = flatten([
    local.common_patches_by_node[each.key],
    file("${path.module}/files/cp-config.yaml"),
    templatefile("${path.module}/files/inline-manifests.yaml.tmpl", {
      manifests = {}
    }),
    file("${path.module}/files/permissive-admission.yaml"),
    file("${path.module}/files/cp-scheduling.yaml"),
    templatefile("${path.module}/files/cp-network-rules.yaml.tmpl", {
      pod_subnets            = var.pod_subnets,
      control_plane_node_ips = local.tailscale_cidrs,
      node_ips               = local.tailscale_cidrs,
    }),
    file("${path.module}/files/talos-api-kube-system.yaml"),
    templatefile("${path.module}/files/oidc.yaml.tmpl", {
      cluster_oidc_issuer    = "https://${var.cluster_oidc_issuer_host}",
      cluster_oidc_client_id = var.cluster_oidc_client_id,
    }),
  ])
}

data "talos_machine_configuration" "worker_nodes" {
  for_each         = local.worker_nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = flatten([
    local.common_patches_by_node[each.key],
    templatefile("${path.module}/files/worker-network-rules.yaml.tmpl", {
      node_ips = local.tailscale_cidrs,
    }),
  ])
}
