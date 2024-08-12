variable "lets_encrypt_email" {
  description = "Email to use for Lets Encrypt certs"
  type        = string
}

variable "services_hostname_suffix" {
  description = "Domain suffix common to all services gateway routes"
  type        = string
}

provider "kubernetes" {
  host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
  client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

resource "kubernetes_namespace" "flux-system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_secret" "sops" {
  metadata {
    name      = "sops"
    namespace = kubernetes_namespace.flux-system.metadata[0].name
  }

  data = {
    "identity.agekey" = var.flux_sops_age_key
  }
}

data "tls_public_key" "flux_ssh" {
  private_key_openssh = var.flux_ssh_private_key
}

resource "kubernetes_secret" "deploy-key" {
  metadata {
    name      = "deploy-key"
    namespace = kubernetes_namespace.flux-system.metadata[0].name
  }

  data = {
    identity       = var.flux_ssh_private_key
    "identity.pub" = data.tls_public_key.flux_ssh.public_key_openssh
    known_hosts    = <<-EOF
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
    EOF
  }
}

resource "helm_release" "flux" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  name       = "flux"
  namespace  = kubernetes_namespace.flux-system.metadata[0].name

  values = [
    <<-EOT
    notificationController:
      create: false
    imageReflectionController:
      create: false
    imageAutomationController:
      create: false
    EOT
  ]
}

resource "helm_release" "flux-sync-base" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base"
  namespace  = helm_release.flux.namespace

  values = [
    <<-EOT
    gitRepository:
      spec:
        interval: 10m0s
        ref:
          branch: main
        secretRef:
          name: deploy-key
        url: ssh://git@github.com/${var.github_repo}
    kustomization:
      spec:
        interval: 10m0s
        path: ./k8s/base
        prune: true
        wait: true
        decryption:
          provider: sops
          secretRef:
            name: sops
    EOT
  ]
}

resource "helm_release" "flux-sync-base-config" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base-config"
  namespace  = helm_release.flux.namespace

  values = [
    <<-EOT
    gitRepository:
      spec:
        interval: 10m0s
        ref:
          branch: main
        secretRef:
          name: deploy-key
        url: ssh://git@github.com/${var.github_repo}
    kustomization:
      spec:
        interval: 10m0s
        path: ./k8s/base-config
        prune: true
        wait: true
        dependsOn:
          - name: ${helm_release.flux-sync-base.name}
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substitute:
            lets_encrypt_email: "${var.lets_encrypt_email}"
    EOT
  ]
}

resource "helm_release" "flux-sync-base-services" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base-services"
  namespace  = helm_release.flux.namespace

  values = [
    <<-EOT
    gitRepository:
      spec:
        interval: 10m0s
        ref:
          branch: main
        secretRef:
          name: deploy-key
        url: ssh://git@github.com/${var.github_repo}
    kustomization:
      spec:
        interval: 10m0s
        path: ./k8s/base-services
        prune: true
        wait: true
        dependsOn:
          - name: ${helm_release.flux-sync-base-config.name}
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substitute:
            services_hostname_suffix: "${var.services_hostname_suffix}"
    EOT
  ]
}

resource "helm_release" "flux-sync-apps" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-apps"
  namespace  = helm_release.flux.namespace

  values = [
    <<-EOT
    gitRepository:
      spec:
        interval: 10m0s
        ref:
          branch: main
        secretRef:
          name: deploy-key
        url: ssh://git@github.com/${var.github_repo}
    kustomization:
      spec:
        interval: 10m0s
        path: ./k8s/apps
        prune: true
        wait: true
        dependsOn:
          - name: ${helm_release.flux-sync-base-services.name}
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substitute:
            services_hostname_suffix: "${var.services_hostname_suffix}"
            core_tailscale_ip: "${data.tailscale_device.external_server.addresses[0]}"
    EOT
  ]
}
