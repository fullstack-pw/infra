locals {
  workload      = var.workload[terraform.workspace]
  secrets_json  = jsondecode(file("${path.module}/tmp/secrets.json"))
  vault_secrets = local.secrets_json

}
