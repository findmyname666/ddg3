output "cname_record_id" {
  value       = cloudflare_dns_record.cname.id
  description = "The ID of the CNAME record"
}

output "cname_record_name" {
  value       = cloudflare_dns_record.cname.name
  description = "The name of the CNAME record"
}

output "cname_target" {
  value       = cloudflare_dns_record.cname.content
  description = "The target FQDN of the CNAME record"
}

output "zone_id" {
  value       = data.cloudflare_zone.this.id
  description = "The Cloudflare zone ID"
}

output "zone_name" {
  value       = data.cloudflare_zone.this.name
  description = "The Cloudflare zone name"
}
