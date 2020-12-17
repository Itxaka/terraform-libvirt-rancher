variable "libvirt_uri" {
  default     = "qemu:///system"
  description = "URL of libvirt connection - default to localhost"
}

variable "libvirt_keyfile" {
  default     = ""
  description = "The private key file used for libvirt connection - default to none"
}

variable "pool" {
  default     = "default"
  description = "Pool to be used to store all the volumes"
}

variable "image_uri" {
  default     = ""
  description = "URL of the image to use"
}

variable "network_name" {
  default     = "rancher"
  description = "The virtual network name to use. If provided just use the given one (not managed by terraform), otherwise terraform creates a new virtual network resource"
}


variable "network_mode" {
  type        = string
  default     = "nat"
  description = "Network mode used by the cluster"
}

variable "network_cidr" {
  type        = string
  default     = "10.17.0.0/22"
  description = "Network used by the cluster"
}


variable "ntp_servers" {
  type        = list(string)
  default     = []
  description = "List of NTP servers to configure"
}

variable "authorized_keys" {
  type        = list(string)
  default     = []
  description = "SSH keys to inject into all the nodes"
}

variable "repositories" {
  type        = map(string)
  default     = {}
  description = "Urls of the repositories to mount via cloud-init"
}

variable "packages" {
  type = list(string)

  default = []

  description = "List of packages to install"
}

variable "username" {
  default     = "sles"
  description = "Username for the cluster nodes"
}

variable "master_memory" {
  default     = 8096
  description = "Amount of RAM for a master"
}

variable "master_vcpu" {
  default     = 4
  description = "Amount of virtual CPUs for a master"
}

variable "master_disk_size" {
  default     = "25769803776"
  description = "Disk size (in bytes)"
}

variable "num_nodes" {
  default     = 3
  description = "Number of nodes"
}

variable "node_memory" {
  default     = 8096
  description = "Amount of RAM for a node"
}

variable "node_vcpu" {
  default     = 4
  description = "Amount of virtual CPUs for a node"
}

variable "node_disk_size" {
  default     = "25769803776"
  description = "Disk size (in bytes)"
}

variable "k8s_version" {
  default = ""
}

variable "rancher_version" {
  default = "v2.5.3"
}

variable "rancher_password" {
  default = "admin"
}