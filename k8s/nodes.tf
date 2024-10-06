resource "kubernetes_labels" "nodes" {
  for_each = var.node_labels
  api_version = "v1"
  kind        = "Node"
  field_manager = "terraform-labels"

  metadata {
    name = each.key
  }

  labels = each.value
}

resource "kubernetes_node_taint" "this" {
  for_each = var.node_taints
  metadata {
    name = each.key
  }
  dynamic "taint" {
    for_each = each.value
    content {
      key = taint.key
      value = split(":", taint.value)[0]
      effect = split(":", taint.value)[1]
    }
  }
}
