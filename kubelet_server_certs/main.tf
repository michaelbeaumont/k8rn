terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }
  }
}

variable "nodes" {
  description = "All nodes to apply kubelet server config to"
}

variable "machine_configuration" {
  description = "Base machine configuration"
  ephemeral = true
  sensitive = true
}

variable "endpoint" {
  description = "Talos API endpoint"
}

variable "client_configuration" {
  description = "Talos client configuration"
  ephemeral = true
  sensitive = true
}

resource "talos_machine_configuration_apply" "kubelet_server" {
  for_each                       = var.nodes
  client_configuration_wo        = var.client_configuration
  machine_configuration_input_wo = var.machine_configuration[each.key]
  node                           = each.key
  endpoint                       = var.endpoint
  config_patches = [
    <<-EOT
    machine:
      kubelet:
        extraArgs:
          rotate-server-certificates: true
    EOT
  ]
}

