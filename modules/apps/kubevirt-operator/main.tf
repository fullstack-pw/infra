terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

locals {
  cdi_version      = "v1.62.0"
  kubevirt_version = "v1.5.1"
}

data "http" "kubevirt_operator_yaml" {
  url = "https://github.com/kubevirt/kubevirt/releases/download/${local.kubevirt_version}/kubevirt-operator.yaml"
}

data "kubectl_file_documents" "kubevirt_operator_yaml" {
  content = data.http.kubevirt_operator_yaml.response_body
}

resource "kubectl_manifest" "kubevirt_operator" {
  for_each  = data.kubectl_file_documents.kubevirt_operator_yaml.manifests
  yaml_body = each.value
}

data "http" "cdi_operator_yaml" {
  url = "https://github.com/kubevirt/containerized-data-importer/releases/download/${local.cdi_version}/cdi-operator.yaml"
}

data "kubectl_file_documents" "cdi_operator_yaml" {
  content = data.http.cdi_operator_yaml.response_body
}

resource "kubectl_manifest" "cdi_operator" {
  for_each  = data.kubectl_file_documents.cdi_operator_yaml.manifests
  yaml_body = each.value
}
