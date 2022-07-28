terraform {
  required_version = "~> 1.0.11"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.60.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

resource "google_compute_subnetwork" "jupyterstudio_subnetwork" {
  name          = "jupyterstudio-subnetwork-${random_id.instance_name_suffix.hex}"
  ip_cidr_range = "192.168.255.0/24"
  region        = var.region
  network       = google_compute_network.jupyterstudio_network.id
}


resource "google_compute_network" "jupyterstudio_network" {
    name           = "jupyterstudio-network-${random_id.instance_name_suffix.hex}"
    auto_create_subnetworks = false
}

# Allow http/s and ssh into that machine
resource "google_compute_firewall" "jupyterstudio_firewll" {
  name    = "jupyter-firewall-${random_id.instance_name_suffix.hex}"
  network = google_compute_network.jupyterstudio_network.name

  allow {
    protocol                 = "tcp"
    ports                    = ["80", "443", "8787", "22"]
  }

  target_tags = ["jupyterstudio-firewall"]
}

resource "random_id" "instance_name_suffix" {
  byte_length = 4
}


resource "google_dns_record_set" "set" {
  name         = "${var.domain}."
  type         = "A"
  ttl          = 10
  managed_zone = var.managed_dns_zone
  rrdatas      = [google_compute_instance.jupyterstudio.network_interface.0.access_config.0.nat_ip]
}

resource "google_compute_instance" "jupyterstudio" {
  name                    = "jupyterstudio-${random_id.instance_name_suffix.hex}"
  machine_type            = var.jupyterstudio_machine_config.machine_type
  tags                    = ["jupyterstudio-firewall"]


  metadata_startup_script = templatefile("provision.sh", 
    { 
      domain=var.domain,
      admin_email=var.admin_email
    }
  )

  boot_disk {
    initialize_params {
      image = var.jupyterstudio_os_image
      size = var.jupyterstudio_machine_config.disk_size_gb
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.jupyterstudio_subnetwork.name
    access_config {
      // creates a public IP
    }
  }
}
