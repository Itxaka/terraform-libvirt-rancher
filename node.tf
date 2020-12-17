data "template_file" "node_repositories" {
  template = file("cloud-init/repository.yaml")
  count = length(var.repositories)

  vars = {
    repository_url = element(values(var.repositories), count.index)
    repository_name = element(keys(var.repositories), count.index)
  }
}

data "template_file" "node_commands" {
  template = file("cloud-init/commands.yaml")
}

data "template_file" "node_ntp" {
  count = length(var.ntp_servers) > 0 ? 1 : 0
  template = file("cloud-init/ntp.yaml")
  vars = {
    ntp_servers = join("\n", formatlist("    - %s", var.ntp_servers))
  }
}

data "template_file" "node-cloud-init" {
  template = file("cloud-init/cloud_init.yaml")
  count    = var.num_nodes

  vars = {
    authorized_keys = join("\n", formatlist("  - %s", var.authorized_keys))
    repositories = join("\n", data.template_file.node_repositories.*.rendered)
    ntp = length(data.template_file.ntp) > 0 ? join("\n", data.template_file.node_ntp.*.rendered) : ""
    packages = join("\n", formatlist("    - %s", var.packages))
    commands = join("\n", data.template_file.node_commands.*.rendered)
    username = var.username
    hostname = format("node-%02g", count.index)
  }
}

resource "libvirt_volume" "node" {
  count = var.num_nodes
  name = "node-${format("%02g", count.index)}-volume"
  pool = var.pool
  size = var.node_disk_size
  base_volume_id = libvirt_volume.img.id
}

resource "libvirt_cloudinit_disk" "node" {
  count = var.num_nodes
  name = "node-cloudinit-disk-${count.index}"
  pool = var.pool
  user_data = data.template_file.node-cloud-init[count.index].rendered
}


resource "libvirt_domain" "node" {
  count = var.num_nodes
  name = format("node-%02g", count.index)
  memory = var.node_memory
  vcpu = var.node_vcpu
  cloudinit = element(libvirt_cloudinit_disk.node.*.id, count.index)

  cpu = {
    mode = "host-passthrough"
  }

  //noinspection HCLUnknownBlockType
  disk {
    volume_id = element(libvirt_volume.node.*.id, count.index)
  }

  //noinspection HCLUnknownBlockType
  network_interface {
    network_name = var.network_name
    network_id = libvirt_network.network.id
    hostname = format("node-%02g", count.index)
    wait_for_lease = true
  }

  //noinspection HCLUnknownBlockType
  graphics {
    type = "vnc"
    listen_type = "address"
  }
}

resource "null_resource" "node_wait_cloudinit" {
  count = var.num_nodes
  depends_on = [
    libvirt_domain.node]

  connection {
    //noinspection HILUnresolvedReference
    host = element(libvirt_domain.node.*.network_interface.0.addresses.0, count.index)
    user = var.username
    type = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait > /dev/null",
    ]
  }
}

resource "null_resource" "configure_rancher_node" {
  depends_on = [null_resource.master_wait_cloudinit]
  count = var.num_nodes
  connection {
    //noinspection HILUnresolvedReference
    host = element(libvirt_domain.node.*.network_interface.0.addresses.0, count.index)
    user = var.username
    type = "ssh"
  }

  provisioner "file" {
    source = "configure_rancher_node.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh ${local.master_ip} ${var.rancher_password} ${var.rancher_version}",
    ]
  }
}
