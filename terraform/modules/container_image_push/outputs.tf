output "image_references" {
  value = {
    for key, img in var.images : key => {
      name      = img.name
      tag       = img.tag
      full_path = "${var.acr_login_server}/${img.name}:${img.tag}"
    }
  }
  description = "Map of built image references with full paths"
}

output "pushed_images" {
  value = [
    for key, img in var.images : "${var.acr_login_server}/${img.name}:${img.tag}"
  ]
  description = "List of pushed image full paths"
}
