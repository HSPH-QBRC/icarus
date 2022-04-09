variable "git_commit" {
  description = "GitHub repo code commit or branch name"
  type        = string
  default     = "develop"
}

variable "site_url" {
  description = "URL of the site"
  type        = string
  default     = "https://covid.ivyplus.net"
}

variable "ssh_key_pair_name" {
  description = "Web server SSH key pair name"
  type        = string
  default     = "icarus-admin"
}
