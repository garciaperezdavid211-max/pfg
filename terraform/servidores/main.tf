terraform {
  required_providers {
    proxmox = {
        source = "bpg/proxmox"
        version = "0.106.0"
    }
  }
}
resource "proxmox_virtual_environment_file" "mariadb_master_script" {
  content_type = "snippets"
  datastore_id = "local" # ◄ Tu almacenamiento local que ya tiene snippets activos
  node_name    = "proxmox"

  source_raw {
    data = <<-EOF
    #cloud-config
    write_files:
      - path: /tmp/deploy.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          until ping -c 1 github.com &>/dev/null; do sleep 2; done
          apt-get update
          apt-get install -y software-properties-common git python3-mysqldb
          add-apt-repository --yes --update ppa:ansible/ansible
          apt-get install -y ansible
          cd /tmp
          git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
          cd config-repo/ansible/playbooks
          ansible-playbook mariadb_setup.yaml -e "mysql_replication_role=master"

    runcmd:
      - /tmp/deploy.sh
    EOF

    file_name = "mariadb-master-init.sh" 
  }
}
# 1. MariaDB Servers (2 máquinas)
resource "proxmox_virtual_environment_vm" "mariadb_server1" {
  name      = "mariadb-1"
  node_name = var.target_node
  vm_id     = 200
  agent {
    enabled = false
  }
  clone {
    vm_id = 108
  }
  cpu { cores = 2 }
  memory { dedicated = 4096 }

  network_device {
    bridge = "vmbr1"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 50
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }
    ip_config {
      ipv4 {
        address = "192.168.1.30/24"
        gateway = "192.168.1.1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.mariadb_master_script.id
  }
}
resource "proxmox_virtual_environment_file" "mariadb_slave_script" {
  content_type = "snippets"
  datastore_id = "local" # ◄ Tu almacenamiento local que ya tiene snippets activos
  node_name    = "proxmox"

  source_raw {
    data = <<-EOF
    #cloud-config
    write_files:
      - path: /tmp/deploy.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          until ping -c 1 github.com &>/dev/null; do sleep 2; done
          apt-get update
          apt-get install -y software-properties-common git python3-mysqldb
          add-apt-repository --yes --update ppa:ansible/ansible
          apt-get install -y ansible
          cd /tmp
          git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
          cd config-repo/ansible/playbooks
          ansible-playbook mariadb_setup.yaml -e "mysql_replication_role=slave"

    runcmd:
      - /tmp/deploy.sh
    EOF

    file_name = "mariadb-slave-init.sh" 
  }
}
resource "proxmox_virtual_environment_vm" "mariadb_server2" {
  name      = "mariadb-2"
  node_name = var.target_node
  vm_id     = 201
  agent {
    enabled = false
  }
  clone {
    vm_id = 102
  }
  cpu { cores = 2 }
  memory { dedicated = 4096 }

  network_device {
    bridge = "vmbr1"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 50
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }
    ip_config {
      ipv4 {
        address = "192.168.1.31/24"
        gateway = "192.168.1.1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.mariadb_slave_script.id
  }
  depends_on = [ proxmox_virtual_environment_vm.mariadb_server1 ]
}
resource "proxmox_virtual_environment_file" "apache_init_script" {
  content_type = "snippets"
  datastore_id = "local" # ◄ Tu almacenamiento local que ya tiene snippets activos
  node_name    = "proxmox"

  source_raw {
    data = <<-EOF
    #cloud-config
    write_files:
      - path: /tmp/deploy.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          until ping -c 1 github.com &>/dev/null; do sleep 2; done
          apt-get update
          apt-get install -y software-properties-common git python3-mysqldb
          add-apt-repository --yes --update ppa:ansible/ansible
          apt-get install -y ansible
          cd /tmp
          git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
          cd config-repo/ansible/playbooks
          ansible-playbook apache_setup.yaml"

    runcmd:
      - /tmp/deploy.sh
    EOF
    
    file_name = "apache-init.sh" 
  }
  }
# 2. Apache Web Servers
resource "proxmox_virtual_environment_vm" "apache1" {
  name      = "Apache-1"
  node_name = var.target_node
  vm_id     = 300
    agent {
      enabled = false
    }

  clone {
    vm_id = 103
  }

  cpu { cores = 2 }
  memory { dedicated = 4096 }

  network_device {
    bridge = "vmbr2"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }

    ip_config {
      ipv4 {
        address = "192.168.2.10/24"
        gateway = "192.168.2.1"
      }
    }
      user_data_file_id = proxmox_virtual_environment_file.apache_init_script.id
    }
  depends_on = [ proxmox_virtual_environment_vm.mariadb_server2 ]
}

resource "proxmox_virtual_environment_vm" "apache2" {
  name      = "Apache-2"
  node_name = var.target_node
  vm_id     = 301
    agent {
      enabled = false
    }

  clone {
    vm_id = 104
  }

  cpu { cores = 2 }
  memory { dedicated = 4096 }

  network_device {
    bridge = "vmbr2"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }
    ip_config {
      ipv4 {
        address = "192.168.2.11/24"
        gateway = "192.168.2.1"
      }
    }
        user_data_file_id = proxmox_virtual_environment_file.apache_init_script.id
  }
  depends_on = [ proxmox_virtual_environment_vm.apache1 ]
}
resource "proxmox_virtual_environment_file" "haproxy_init_script" {
  content_type = "snippets"
  datastore_id = "local" # ◄ Tu almacenamiento local que ya tiene snippets activos
  node_name    = "proxmox"

  source_raw {
    data = <<-EOF
    #cloud-config
    write_files:
      - path: /tmp/deploy.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          until ping -c 1 github.com &>/dev/null; do sleep 2; done
          apt-get update
          apt-get install -y software-properties-common git python3-mysqldb
          add-apt-repository --yes --update ppa:ansible/ansible
          apt-get install -y ansible
          cd /tmp
          git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
          cd config-repo/ansible/playbooks
          ansible-playbook haproxy_setup.yaml"

    runcmd:
      - /tmp/deploy.sh
    EOF

    file_name = "haproxy-init.sh" 
  }
}
# 3. HAProxy
resource "proxmox_virtual_environment_vm" "haproxy" {
  name      = "haproxy-01"
  node_name = var.target_node
  vm_id     = 400
  agent {
    enabled = false
  }
  clone {
    vm_id = 105
  }
  network_device {
    bridge = "vmbr2"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }
    ip_config {
      ipv4 {
        address = "192.168.2.20/24"
        gateway = "192.168.2.1"
      }
    }
      user_data_file_id = proxmox_virtual_environment_file.haproxy_init_script.id
  }
  depends_on = [ proxmox_virtual_environment_vm.apache2 ]
}
resource "proxmox_virtual_environment_file" "zabbix_init_script" {
  content_type = "snippets"
  datastore_id = "local" # ◄ Tu almacenamiento local que ya tiene snippets activos
  node_name    = "proxmox"

  source_raw {
    data = <<-EOF
    #cloud-config
    write_files:
      - path: /tmp/deploy.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          until ping -c 1 github.com &>/dev/null; do sleep 2; done
          apt-get update
          apt-get install -y software-properties-common git python3-mysqldb
          add-apt-repository --yes --update ppa:ansible/ansible
          apt-get install -y ansible
          cd /tmp
          git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
          cd config-repo/ansible/playbooks
          ansible-playbook zabbix_setup.yaml"

    runcmd:
      - /tmp/deploy.sh
    EOF

    file_name = "zabbix-init.sh" 
  }
}
# 4. Zabbix Server
resource "proxmox_virtual_environment_vm" "zabbix_server" {
  name      = "zabbix-server"
  node_name = var.target_node
  vm_id     = 500
  agent {
    enabled = false
  }
  clone {
    vm_id = 106
  }
  cpu { cores = 2 }
  memory { dedicated = 4096 }

  network_device {
    bridge = "vmbr1"
    model = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 50
  }
  initialization {
    user_account {
      username = "ubuntu"
      password = "1234"
      keys     = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC21C0XJW0VH5Pdf0tzAgM49zG+WpRShbdmINqzTK3qs3gsMA+dYA7HEVgdBmNVv8NSRpXjqKVsn7CGK6M8E66CUt8QTdptGI60dKxAGrAECZYSLQ9D44f3jEFEjSKG6D4PdUJS5qqmHQa4gMEIqkmmqZCzlYoXqHUsQ78XOR4TWkRKcQx286cQDQlbEUW0pbaiZ6O7MZemN2vtFEZfQHL18ApIM7wtgPnF/tCScxSZRPzHkDL3hJdEeUCHiU169u6Ct7rpjm9o+yXPdzcqpdPr0c68XOZwtXRNQZ4f/Dqclz5QK1wxM4Fvro8NvZILTX98OzOm78dzJqgyyYBpTz2S1gkY8DMc0GaGQLA322xe62KcguPhHh10vpYpcQt7mfUH5P1zQTvXsMJigTjLzFfStm6iGAF8ytY4PICwIzIvUlcPvemSmhIEbnrLwAM1yqeUY9AqVFeQJuMZynIhVBV2BVj9J3CaAAxs8FAc24H7Xs6jvlawMrEPEognzRNI7c= bosonit\\david.garcia@L2202013"] 
    }
    ip_config {
      ipv4 {
        address = "192.168.1.50/24"
        gateway = "192.168.1.1"
      }
    }
      user_data_file_id = proxmox_virtual_environment_file.zabbix_init_script.id
  }
  depends_on = [ proxmox_virtual_environment_vm.haproxy ]
}