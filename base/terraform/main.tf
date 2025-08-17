resource "libvirt_pool" "k8s_pool" {
  name = "k8s-pool"
  type = "dir"

  target {
    path = "/tmp/k8s-pool-ubuntu"
  }
}

resource "libvirt_network" "k8s_net" {
  name      = "k8s-net"
  mode      = "nat"
  autostart = true
  addresses = ["192.168.30.1/24"]
}


resource "libvirt_volume" "ubuntu-qcow2" {
  name   = "ubuntu-qcow2"
  pool   = libvirt_pool.k8s_pool.name
  source = "/home/jeff/Workspace/jeff/packer/build-jammy-base/ubuntu-jammy-base.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "ubuntu-master-qcow2" {
  name           = "ubuntu-base-qcow2"
  pool           = libvirt_pool.k8s_pool.name
  size           = 20 * 1024 * 1024 * 1024
  base_volume_id = libvirt_volume.ubuntu-qcow2.id
  format         = "qcow2"
}

resource "libvirt_volume" "ubuntu-worker-qcow2" {
  count          = 2
  name           = "ubuntu-${count.index}-qcow2"
  pool           = libvirt_pool.k8s_pool.name
  size           = 20 * 1024 * 1024 * 1024
  base_volume_id = libvirt_volume.ubuntu-qcow2.id
  format         = "qcow2"
}

data "template_file" "user_data_master" {
  template = file("${path.module}/cfg/cloud_init.cfg")
  vars = {
    hostname = "k8s-master-0"
  }
}

data "template_file" "user_data_worker" {
  count    = 2
  template = file("${path.module}/cfg/cloud_init.cfg")
  vars = {
    hostname = "k8s-worker-${count.index}"
  }
}

data "template_file" "network_config_master" {
  template = file("${path.module}/cfg/network_config.cfg")
  vars = {
    ipaddr = "192.168.30.2/24"
  }
}

data "template_file" "network_config_worker" {
  count    = 2
  template = file("${path.module}/cfg/network_config.cfg")
  vars = {
    ipaddr = element(["192.168.30.3/24", "192.168.30.4/24"], count.index)
  }
}

resource "libvirt_cloudinit_disk" "masterinit" {
  name           = "masterinit.iso"
  user_data      = data.template_file.user_data_master.rendered
  network_config = data.template_file.network_config_master.rendered
  pool           = libvirt_pool.k8s_pool.name
}

resource "libvirt_cloudinit_disk" "workerinit" {
  count          = 2
  name           = "workerinit-${count.index}.iso"
  user_data      = data.template_file.user_data_worker[count.index].rendered
  network_config = data.template_file.network_config_worker[count.index].rendered
  pool           = libvirt_pool.k8s_pool.name
}

resource "libvirt_domain" "k8s-master" {
  name   = "k8s-master-0"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.masterinit.id

  network_interface {
    network_id = libvirt_network.k8s_net.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ubuntu-master-qcow2.id
  }
}

resource "libvirt_domain" "k8s_worker" {
  count  = 2
  name   = "k8s-worker-${count.index}"
  memory = 4096
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.workerinit[count.index].id

  network_interface {
    network_id = libvirt_network.k8s_net.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ubuntu-worker-qcow2[count.index].id
  }
}