resource "github_organization_settings" "org" {
  billing_email = "pedropasouza@outlook.com"
  name          = "homelabz-eu"
  description   = "Homelab infrastructure and applications"
  blog          = "https://homelabz.eu"
}

resource "github_repository" "repo" {
  for_each = var.repositories

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

  has_issues   = true
  has_projects = false
  has_wiki     = false

  delete_branch_on_merge = true
  auto_init              = false
}
