variable "cname_target" {
  type        = string
  description = "Target FQDN for CNAME record"
}

variable "comment" {
  type        = string
  description = "Comment for the DNS records"
  default     = "Managed by Terraform - DDG3"
}

variable "record_name" {
  type        = string
  description = "The DNS record name (subdomain or @ for root). For 'www.example.com', use 'www'. For 'example.com', use '@'"
}

variable "ttl" {
  type        = number
  description = "TTL for DNS records in seconds. Use 1 for automatic (Cloudflare default). Use 120-300 for Let's Encrypt challenges"
  default     = 10
}

variable "zone_name" {
  type        = string
  description = "The Cloudflare zone (domain) name, e.g., 'example.com'"
}
