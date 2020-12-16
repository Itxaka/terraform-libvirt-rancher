output "master_ip" {
  value = local.master_ip
}

output "node_ip" {
  //noinspection HILUnresolvedReference
  value = zipmap(
    libvirt_domain.node.*.network_interface.0.hostname,
    libvirt_domain.node.*.network_interface.0.addresses.0,
  )
}