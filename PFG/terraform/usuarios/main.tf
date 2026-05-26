terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.106.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "Windows_11"{
  count     = 1
  name      = "equipo-${count.index + 1}"
  node_name = var.target_node
  vm_id     = 1000 + count.index
  clone {
    vm_id = 100
    full  = true
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr3"
  }
  initialization {
    ip_config{
      ipv4{
        address="dhcp"
      }
    }
    dns{
      servers=["192.168.3.1"]
    }
  }
}