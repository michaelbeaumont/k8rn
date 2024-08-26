locals {
  factory_schematic = <<-EOF
    customization:
        systemExtensions:
            officialExtensions:
                - siderolabs/i915-ucode
                - siderolabs/intel-ucode
                - siderolabs/tailscale
  EOF
}

data "external" "factory_image" {
  program = [
    "bash", "-c",
  "curl --silent -X POST https://factory.talos.dev/schematics --data-binary @- << EOF\n${local.factory_schematic}EOF"]
  query = {}
}

resource "talos_machine_secrets" "this" {
  talos_version = "v1.7.5"
}

locals {
  talos_installer_uri = "factory.talos.dev/installer-secureboot/${data.external.factory_image.result.id}:${var.talos_version}"
}

data "talos_machine_configuration" "control_plane_nodes" {
  for_each         = var.control_plane_nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = compact([
    templatefile("${path.module}/files/install-disk-and-hostname.yaml.tmpl", {
      talos_version             = var.talos_version
      installer_uri             = local.talos_installer_uri
      hostname                  = local.hostnames[each.key]
      dns_loadbalancer_hostname = local.dns_loadbalancer_hostname
      install_disk              = "/dev/nvme0n1"
      cluster_endpoint_host     = local.dns_loadbalancer_hostname
      pod_subnets               = var.pod_subnets
      service_subnets           = var.service_subnets
    }),
    file("${path.module}/files/cp-config.yaml"),
    templatefile("${path.module}/files/inline-manifests.yaml.tmpl", {
      manifests = {
        "install-cilium"  = file("${path.module}/files/cilium-install-job-manifests.yaml"),
        "block-tailscale" = file("${path.module}/files/block-tailscale.yaml"),
      }
    }),
    file("${path.module}/files/permissive-admission.yaml"),
    file("${path.module}/files/cp-scheduling.yaml"),
    templatefile("${path.module}/files/encrypt-kms.patch.yaml.tmpl", {
      kms_endpoint = var.kms_endpoint
    }),
    templatefile("${path.module}/files/tailscale.yaml.tmpl", {
      tailscale_key = tailscale_tailnet_key.unsigned-cp[each.key].key
    }),
    file("${path.module}/files/watchdog.yaml"),
    templatefile("${path.module}/files/cp-network-rules.yaml.tmpl", {
      pod_subnets = var.pod_subnets
      control_plane_node_ips = [
        "100.64.0.0/10",
        "fd7a:115c:a1e0::/64",
      ],
      node_ips = [
        "100.64.0.0/10",
        "fd7a:115c:a1e0::/64",
      ],
      vxlan_port = "8472 # cilium-specific"
    }),
    templatefile("${path.module}/files/hubble-peer-rules.yaml.tmpl", {
      pod_subnets = var.pod_subnets,
      node_ips = [
        "100.64.0.0/10",
        "fd7a:115c:a1e0::/64",
      ],
    }),
  ])
}

data "talos_machine_configuration" "worker_nodes" {
  for_each         = var.worker_nodes
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = compact([
    templatefile("${path.module}/files/install-disk-and-hostname.yaml.tmpl", {
      talos_version             = var.talos_version
      installer_uri             = local.talos_installer_uri
      hostname                  = local.hostnames[each.key]
      dns_loadbalancer_hostname = local.dns_loadbalancer_hostname
      install_disk              = "/dev/nvme0n1"
      cluster_endpoint_host     = local.dns_loadbalancer_hostname
      pod_subnets               = var.pod_subnets
      service_subnets           = var.service_subnets
    }),
    file("${path.module}/files/openebs.patch.yaml"),
    contains(var.mayastor_io_engine_nodes, each.key) ? file("${path.module}/files/mayastor.patch.yaml") : "",
    templatefile("${path.module}/files/encrypt-kms.patch.yaml.tmpl", {
      kms_endpoint = var.kms_endpoint
    }),
    templatefile("${path.module}/files/tailscale.yaml.tmpl", {
      tailscale_key = tailscale_tailnet_key.unsigned-worker[each.key].key
    }),
    file("${path.module}/files/watchdog.yaml"),
    templatefile("${path.module}/files/worker-network-rules.yaml.tmpl", {
      node_ips = [
        "100.64.0.0/10",
        "fd7a:115c:a1e0::/64",
      ],
      vxlan_port = "8472 # cilium-specific"
    }),
    templatefile("${path.module}/files/hubble-peer-rules.yaml.tmpl", {
      pod_subnets = var.pod_subnets,
      node_ips = [
        "100.64.0.0/10",
        "fd7a:115c:a1e0::/64",
      ],
    }),
  ])
}
