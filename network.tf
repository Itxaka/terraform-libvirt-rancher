resource "libvirt_network" "network" {
  name   = var.network_name
  mode   = var.network_mode

  //noinspection HCLUnknownBlockType
  dns {
    enabled = true
  }

  addresses = [var.network_cidr]
}
