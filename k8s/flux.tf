variable "github_repo" {
  description = "The github organization/repo where this repository is reachable"
  type        = string
}

variable "lets_encrypt_email" {
  description = "Email to use for Lets Encrypt certs"
  type        = string
}

variable "services_hostname_suffix" {
  description = "Domain suffix common to all services gateway routes"
  type        = string
}

variable "cluster_oidc_issuer_host" {
  description = "The issuer hostname to use for cluster OIDC authentication"
  type        = string
}

resource "kubernetes_namespace_v1" "flux-system" {
  metadata {
    name = "flux-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
  wait_for_default_service_account = false
}

resource "kubernetes_secret_v1" "sops" {
  metadata {
    name      = "sops"
    namespace = kubernetes_namespace_v1.flux-system.metadata[0].name
  }
  wait_for_service_account_token = false

  data = {
    "identity.agekey" = var.flux_sops_age_key
  }
}

data "tls_public_key" "flux_ssh" {
  private_key_openssh = var.flux_ssh_private_key
}

resource "kubernetes_secret_v1" "deploy-key" {
  metadata {
    name      = "deploy-key"
    namespace = kubernetes_namespace_v1.flux-system.metadata[0].name
  }
  wait_for_service_account_token = false

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
  namespace  = kubernetes_namespace_v1.flux-system.metadata[0].name
  version    = "2.17.2"

  values = [
    <<-EOT
    notificationController:
      create: false
    imageReflectionController:
      create: false
    imageAutomationController:
      create: false
    kustomizeController:
      container:
        additionalArgs:
          - --feature-gates
          - CancelHealthCheckOnNewRevision=true
    EOT
  ]
}

resource "helm_release" "flux-sync-prebase" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-prebase"
  namespace  = helm_release.flux.namespace
  version    = "1.14.1"

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
        path: ./k8s/manifests/prebase
        prune: true
        wait: true
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substitute:
            services_hostname_suffix: "${var.services_hostname_suffix}"
            cluster_oidc_issuer_host: "${var.cluster_oidc_issuer_host}"
            local_cidr_ipv4: "${var.local_cidr.ipv4}"
            local_cidr_ipv6: "${var.local_cidr.ipv6}"
            kms_endpoint_domain: "${provider::corefunc::url_parse(var.kms_endpoint).hostname}"
    EOT
  ]
}

resource "helm_release" "flux-sync-base" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base"
  namespace  = helm_release.flux.namespace
  version    = "1.14.1"

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
        path: ./k8s/manifests/base
        prune: true
        wait: true
        dependsOn:
          - name: ${helm_release.flux-sync-prebase.name}
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substitute:
            openebs_etcd_replicaCount: "${var.openebs_etcd_replicaCount}"
            kms_endpoint: "${var.kms_endpoint}"
    EOT
  ]
}

resource "helm_release" "flux-sync-base-config" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base-config"
  namespace  = helm_release.flux.namespace
  version    = "1.14.1"

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
        path: ./k8s/manifests/base-config
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
            restic_remote_password: "${var.restic_remote_password}"
            openebs_diskpool_partition_label: "${var.openebs_diskpool_partition_label}"
            kms_endpoint_domain: "${provider::corefunc::url_parse(var.kms_endpoint).hostname}"
    EOT
  ]
}

resource "helm_release" "flux-sync-base-services" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-base-services"
  namespace  = helm_release.flux.namespace
  version    = "1.14.1"

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
        path: ./k8s/manifests/base-services
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
            local_cidr_ipv4: "${var.local_cidr.ipv4}"
            local_cidr_ipv6: "${var.local_cidr.ipv6}"
            services_hostname_suffix: "${var.services_hostname_suffix}"
    EOT
  ]
}

resource "helm_release" "flux-sync-apps" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  name       = "flux-sync-apps"
  namespace  = helm_release.flux.namespace
  version    = "1.14.1"

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
        path: ./k8s/manifests/apps
        prune: true
        wait: true
        dependsOn:
          - name: ${helm_release.flux-sync-base-services.name}
        decryption:
          provider: sops
          secretRef:
            name: sops
        postBuild:
          substituteFrom:
            - kind: Secret
              name: restic-remote-base
            - kind: Secret
              name: restic-remote-password
          substitute:
            services_hostname_suffix: "${var.services_hostname_suffix}"
    EOT
  ]
}
