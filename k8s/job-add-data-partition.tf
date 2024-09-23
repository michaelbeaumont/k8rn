// It really sucks this has to be done in HCL like this, kubernetes_manifest
// tries to call the API server
// But it's temporary, just until Talos handles this
resource "kubernetes_job_v1" "add_data_partition" {
  for_each = var.add_data_partition_nodes
  timeouts {
    create = "3m"
    update = "3m"
    delete = "3m"
  }
  metadata {
    name      = "add-data-partition-${each.value}"
    namespace = helm_release.cilium.namespace
  }
  spec {
    template {
      metadata {
      }
      spec {
        node_name = each.value
        container {
          name              = "add-data-partition"
          image             = "docker.io/michaelbeaumont/gdisk:latest"
          image_pull_policy = "IfNotPresent"
          command = [
            "bash", "-c",
            <<-EOT
            set -e
            disk=/dev/nvme0n1
            if [[ -b /dev/disk/by-partlabel/data ]]; then
                echo "Data partition already exists"
                sgdisk -p "$${disk}"
                exit 0
            fi
            sgdisk --new=5:0:0 --change-name=5:data --typecode=5:8300 "$${disk}"
            partprobe
            sgdisk -p "$${disk}"
            EOT
          ]
          security_context {
            privileged = true
          }
          volume_mount {
            mount_path = "/dev"
            name       = "dev"
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
            path = "/dev"
            type = "Directory"
          }
          name = "dev"
        }
      }
    }
  }
}
