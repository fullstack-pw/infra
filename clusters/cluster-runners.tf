module "github_runner" {
  count  = contains(local.workload, "github_runner") ? 1 : 0
  source = "../modules/github-runner"

  namespace          = "actions-runner-system"
  github_owner       = "fullstack-pw"
  arc_chart_version  = "0.23.7"
  runner_image       = "registry.fullstack.pw/github-runner:latest"
  runner_replicas    = 2
  enable_autoscaling = false
}

module "gitlab_runner" {
  count  = contains(local.workload, "gitlab_runner") ? 1 : 0
  source = "../modules/gitlab-runner"

  namespace            = "gitlab"
  service_account_name = "gitlab-runner-sa"
  release_name         = "gitlab-runner"
  chart_version        = "0.71.0"
  concurrent_runners   = 10
  runner_tags          = "k8s-gitlab-runner"
}
