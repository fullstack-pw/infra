resource "cloudflare_zone" "main" {
  account = {
    id = var.cloudflare_account_id
  }
  name = var.cloudflare_zone_name
}
