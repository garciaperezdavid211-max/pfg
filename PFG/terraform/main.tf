terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.106.0"
    }
  }
}
provider "proxmox" {
  endpoint        = var.proxmox_api_url
  api_token   = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true
  ssh {
    agent = true
    username = "root" 
    password = var.contraseña_proxmox
  }
}
module "pfsense" {
  source      = "./pfsense"
  target_node = var.target_node  
}
module "servidores" {
  source      = "./servidores"
  target_node = var.target_node

  depends_on  = [module.pfsense]
}
module "usuarios" {
  source = "./usuarios"
  target_node = var.target_node
  depends_on = [ 
    module.pfsense, 
    module.servidores
    ]
}

