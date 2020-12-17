data "template_file" "repositories" {
  template = file("cloud-init/repository.yaml")
  count    = length(var.repositories)

  vars = {
    repository_url  = element(values(var.repositories), count.index)
    repository_name = element(keys(var.repositories), count.index)
  }
}

data "template_file" "commands" {
  template = file("cloud-init/commands.yaml")
}

data "template_file" "ntp" {
  count    = length(var.ntp_servers) > 0 ? 1 : 0
  template = file("cloud-init/ntp.yaml")
  vars = {
    ntp_servers = join("\n", formatlist("    - %s", var.ntp_servers))
  }
}

data "template_file" "master-cloud-init" {
  template = file("cloud-init/cloud_init.yaml")

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    repositories    = join("\n", data.template_file.repositories.*.rendered)
    ntp             = length(data.template_file.ntp) > 0 ? join("\n", data.template_file.ntp.*.rendered) : ""
    packages        = join("\n", formatlist("    - %s", var.packages))
    commands        = join("\n", data.template_file.commands.*.rendered)
    username        = var.username
    hostname        = "master"
  }
}

resource "libvirt_volume" "master" {
  name           = "master-volume"
  pool           = var.pool
  size           = var.master_disk_size
  base_volume_id = libvirt_volume.img.id
}

resource "libvirt_cloudinit_disk" "master" {
  name      = "master-cloudinit-disk"
  pool      = var.pool
  user_data = data.template_file.master-cloud-init.rendered
}


resource "libvirt_domain" "master" {
  name      = "master-domain"
  memory    = var.master_memory
  vcpu      = var.master_vcpu
  cloudinit = libvirt_cloudinit_disk.master.id

  cpu = {
    mode = "host-passthrough"
  }

  //noinspection HCLUnknownBlockType
  disk {
    volume_id = libvirt_volume.master.id
  }

  //noinspection HCLUnknownBlockType
  network_interface {
    network_name   = var.network_name
    network_id     = libvirt_network.network.id
    hostname       = "master"
    wait_for_lease = true
  }

  //noinspection HCLUnknownBlockType
  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}


resource "null_resource" "master_wait_cloudinit" {
  depends_on = [
  libvirt_domain.master]

  connection {
    //noinspection HILUnresolvedReference
    host = libvirt_domain.master.network_interface.0.addresses.0
    user = var.username
    type = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /dev/null",
    ]
  }
}

resource "null_resource" "configure_rancher_server" {
  depends_on = [null_resource.master_wait_cloudinit]
  connection {
    //noinspection HILUnresolvedReference
    host = libvirt_domain.master.network_interface.0.addresses.0
    user = var.username
    type = "ssh"
  }

  provisioner "file" {
    source      = "configure_rancher_server.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh ${var.rancher_password} ${var.rancher_version} ${local.master_ip} ${var.k8s_version}",
    ]
  }
}


locals {
  //noinspection HILUnresolvedReference
  master_ip = libvirt_domain.master.network_interface.0.addresses.0
}
