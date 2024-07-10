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
  talos_version = var.talos_version
}

locals {
  talos_installer_uri = "factory.talos.dev/installer-secureboot/${data.external.factory_image.result.id}:${var.talos_version}"
}

data "talos_machine_configuration" "this" {
  for_each         = toset([for node in var.control_plane_nodes : node.local_ip])
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version
  config_patches = compact([
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      talos_version             = var.talos_version
      installer_uri             = local.talos_installer_uri
      hostname                  = local.hostnames[each.value]
      dns_loadbalancer_hostname = local.dns_loadbalancer_hostname
      install_disk              = "/dev/nvme0n1"
      cluster_endpoint_host     = local.dns_loadbalancer_hostname
      manifests = [
        file("${path.module}/files/cilium.yaml"),
        file("${path.module}/files/block-tailscale.yaml"),
      ]
    }),
    file("${path.module}/files/permissive-admission.yaml"),
    file("${path.module}/files/openebs.patch.yaml"),
    contains(var.mayastor_io_engine_nodes, each.value) ? file("${path.module}/files/mayastor.patch.yaml") : "",
    file("${path.module}/files/cp-scheduling.yaml"),
    templatefile("${path.module}/templates/encrypt-kms.patch.yaml.tmpl", {
      kms_endpoint = var.kms_endpoint
    }),
    templatefile("${path.module}/templates/tailscale.yaml.tmpl", {
      tailscale_key = tailscale_tailnet_key.unsigned-cp[each.value].key
    }),
  ])
}
