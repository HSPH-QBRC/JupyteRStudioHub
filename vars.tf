variable "project_id" {
  description = "GCP project ID"
}

variable "credentials_file" {
  description = "Path to JSON file with GCP service account key"
}

variable "region" {
  default = "us-east4"
}

variable "zone" {
  default = "us-east4-c"
}

variable "jupyterstudio_machine_config" {
  type    = object({
                machine_type   = string
                disk_size_gb   = number
            })
}

variable "jupyterstudio_os_image" {
    default = "ubuntu-2204-jammy-v20230727"
}

variable "domain"{
  description="The domain to deploy on"
}

variable "managed_dns_zone" {
  description="The GCP managed DNS zone where we will add the new A record for the domain above"
}

variable "admin_email" {
  description="An email for certbot to use."
}