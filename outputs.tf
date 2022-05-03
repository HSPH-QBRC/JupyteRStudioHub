output "jupyterstudio_ip" {
    value = google_compute_instance.jupyterstudio.network_interface.0.access_config.0.nat_ip
}
