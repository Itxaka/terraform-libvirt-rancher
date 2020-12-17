terraform-libvirt-rancher
-------------------------

Deploy a rancher platform with a pre-made 3 cluster node using libvirt

This will create a master node which will run rancher server and X nodes that
will be added to a cluster called quickstart using the latest supported k8s


Requirements
-------------

 - Libvirtd running
 - A local image or remote image to use (tested with SLES15SP2 and openSUSE Leap 15.2)
 - Terraform => 0.13
 - Terraform-provider-libvirt (https://github.com/dmacvicar/terraform-provider-libvirt)
 - Some small configuration


Deploy
-------

 - Create a terraform.tfvars in the root directory with at least the following vars:
    - `image_uri` -> Local or remote image to create the nodes from
    - `username` -> username to ssh into the nodes (i.e. sles on SLES and opensuse in openSUSE)
    - `authorized_keys` -> ssh keys to add to the nodes. These keys should be managed by your ssh-agent, otherwise terraform wont be able to ssh and provision rancher
 - terraform init
 - terraform apply

After terraform is finished you can navigate to the `master_ip` https address to see the rancher login page. Use the default user/pass to login and manage your new quickstart cluster!



Terraform vars
--------------

All the available terraform vars are under `variables.tf` so you can override whatever you need by using a `terraform.tfvars` file.
