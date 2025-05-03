locals {
  cdi_version      = "v1.62.0"
  cdi_operator_url = "https://github.com/kubevirt/containerized-data-importer/releases/download/${local.cdi_version}/cdi-operator.yaml"
  cdi_cr_url       = "https://github.com/kubevirt/containerized-data-importer/releases/download/${local.cdi_version}/cdi-cr.yaml"

}

# Download operator manifest
data "http" "cdi_operator_manifest" {
  url = local.cdi_operator_url
}

# Split the cdi_operator manifest into individual documents
resource "local_file" "cdi_operator_yaml" {
  content  = data.http.cdi_operator_manifest.response_body
  filename = "${path.module}/cdi_operator.yaml"
}

data "kubectl_path_documents" "cdi_operator_docs" {
  pattern = resource.local_file.cdi_operator_yaml.filename
}

# # Apply each document in the cdi_operator manifest
resource "kubectl_manifest" "kubevirt_cdi_operator" {
  for_each  = toset(data.kubectl_path_documents.cdi_operator_docs.documents)
  yaml_body = each.value

  # override_namespace = var.namespace
  wait              = true
  server_side_apply = true

  depends_on = [data.kubectl_path_documents.cdi_operator_docs]
}

# Only proceed with CR installation if requested
data "http" "cdi_cr_manifest" {
  count = var.create_cdi_cr ? 1 : 0
  url   = local.cdi_cr_url
}

resource "local_file" "cdi_cr_yaml" {
  count    = var.create_cdi_cr ? 1 : 0
  content  = data.http.cdi_cr_manifest[0].response_body
  filename = "${path.module}/cdi_cr.yaml"
}

data "kubectl_path_documents" "cdi_cr_docs" {
  count   = var.create_cdi_cr ? 1 : 0
  pattern = resource.local_file.cdi_cr_yaml[0].filename
}

# Apply each document in the CR manifest
resource "kubectl_manifest" "cdi_cr" {
  for_each = var.create_cdi_cr ? toset(data.kubectl_path_documents.cdi_cr_docs[0].documents) : toset([])

  yaml_body = each.value

  # override_namespace = var.namespace
  wait              = true
  server_side_apply = true

  depends_on = [kubectl_manifest.kubevirt_cdi_operator]
}

