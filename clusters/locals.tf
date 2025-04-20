locals {
  workload      = var.workload[terraform.workspace]
  secrets_json  = jsondecode(file("${path.module}/tmp/secrets.json"))
  vault_secrets = local.secrets_json

  secret_data = flatten([
    for path, data in local.secrets_json : [
      for key, value in data : {
        secretKey = key
        remoteRef = {
          key      = replace(path, "kv/cluster-secret-store/secrets/", "")
          property = "data.${key}"
        }
      }
      if startswith(path, "kv/cluster-secret-store/secrets/")
    ]
  ])
}
