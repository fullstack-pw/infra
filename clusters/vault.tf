data "vault_kv_secret_v2" "github_token" {
  count = contains(local.workload, "github_runner") ? 1 : 0
  mount = "kv"
  name  = "github-runner"
}
