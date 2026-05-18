terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.106.0"
    }
  }
}
resource "proxmox_virtual_environment_vm" "pfSense" {
  name      = "pfSense"
  node_name = var.target_node 
  vm_id = 600
  clone {
    vm_id = 109
  }
  agent {
    enabled = false
  }
  cpu {
    cores = 2
  }

  memory {
    dedicated = 4500
  }

  #WAN
  network_device {
    bridge = "vmbr0"
    model = "virtio"
  }
  #LAN
  network_device {
    bridge = "vmbr1"
    model = "virtio"
  }
  #DMZ
  network_device {
    bridge = "vmbr2"
    model = "virtio"
  }
  #OPT1/LAN2
  network_device {
    bridge = "vmbr3"
    model = "virtio"
  }
  disk {
    datastore_id = "local-lvm"
    interface = "scsi0"
    size         = 32
  }
  
}
