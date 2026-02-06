# Get the zone ID from the domain name using filter
data "cloudflare_zone" "this" {
  filter = {
    name = var.zone_name
  }
}

# CNAME record pointing to a target FQDN
resource "cloudflare_dns_record" "cname" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.record_name
  content = var.cname_target
  type    = "CNAME"
  ttl     = var.ttl

  comment = var.comment
}
