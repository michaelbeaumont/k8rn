// It really sucks this has to be done in HCL like this, kubernetes_manifest
// tries to call the API server
resource "kubernetes_job_v1" "set_tailscale_advertise_routes" {
  for_each = var.nodes
  timeouts {
    create = "3m"
    update = "3m"
    delete = "3m"
  }
  metadata {
    name      = "set-tailscale-advertise-routes-${each.value}"
    namespace = "kube-system"
  }
  spec {
    template {
      metadata {
      }
      spec {
        node_name = each.value
        container {
          name              = "set-tailscale-advertise-routes"
          image             = "docker.io/tailscale/tailscale:latest"
          image_pull_policy = "IfNotPresent"
          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
          command = [
            "sh", "-c",
            <<-EOT
            IFS=. read A B C _ < <(echo '$(POD_IP)')
            tailscale --socket /var/run/host/tailscale/tailscaled.sock set --advertise-routes "$${A}.$${B}.$${C}.0/24"
            EOT
          ]
          volume_mount {
            mount_path = "/var/run/host"
            name       = "var-run"
          }
        }
        restart_policy = "OnFailure"
        security_context {
          run_as_non_root = false
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }
        volume {
          host_path {
            path = "/var/run"
            type = "Directory"
          }
          name = "var-run"
        }
      }
    }
  }
}
