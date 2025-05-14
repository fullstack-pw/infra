terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}
module "namespace" {
  source = "../../base/namespace"

  create = var.create_namespace
  name   = var.namespace
  labels = var.namespace_labels
}

data "http" "kubevirt_version" {
  url = "https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt"
}

locals {
  kubevirt_version = trimspace(data.http.kubevirt_version.response_body)
  operator_url     = "https://github.com/kubevirt/kubevirt/releases/download/${local.kubevirt_version}/kubevirt-operator.yaml"
  cr_url           = "https://github.com/kubevirt/kubevirt/releases/download/${local.kubevirt_version}/kubevirt-cr.yaml"
}

# Download operator manifest
data "http" "operator_manifest" {
  url = local.operator_url
}

# Split the operator manifest into individual documents
resource "local_file" "operator_yaml" {
  content  = data.http.operator_manifest.response_body
  filename = "${path.module}/kubevirt_operator.yaml"
}

data "kubectl_path_documents" "operator_docs" {
  pattern = resource.local_file.operator_yaml.filename
}

# Apply each document in the operator manifest
resource "kubectl_manifest" "kubevirt_operator" {
  for_each  = toset(data.kubectl_path_documents.operator_docs.documents)
  yaml_body = each.value

  override_namespace = var.namespace
  wait               = true
  server_side_apply  = true

  depends_on = [data.kubectl_path_documents.operator_docs]
}

# Only proceed with CR installation if requested
data "http" "cr_manifest" {
  count = var.create_kubevirt_cr ? 1 : 0
  url   = local.cr_url
}

resource "local_file" "cr_yaml" {
  count    = var.create_kubevirt_cr ? 1 : 0
  content  = data.http.cr_manifest[0].response_body
  filename = "${path.module}/kubevirt_cr.yaml"
}

data "kubectl_path_documents" "cr_docs" {
  count   = var.create_kubevirt_cr ? 1 : 0
  pattern = resource.local_file.cr_yaml[0].filename
}

# Apply each document in the CR manifest
resource "kubectl_manifest" "kubevirt_cr" {
  for_each = var.create_kubevirt_cr ? toset(data.kubectl_path_documents.cr_docs[0].documents) : toset([])

  yaml_body = each.value

  override_namespace = var.namespace
  wait               = true
  server_side_apply  = true

  depends_on = [kubectl_manifest.kubevirt_operator]
}

