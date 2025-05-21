resource "kubernetes_cluster_role_binding" "oidc_cluster_admin" {
  metadata {
    name = "oidc-cluster-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "Group"
    name      = "oidc:k8rn_admin"
    api_group = "rbac.authorization.k8s.io"
  }
}


