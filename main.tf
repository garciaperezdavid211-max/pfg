resource "aws_vpc" "pfg_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "VPC-PFG-David" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.pfg_vpc.id
  tags   = { Name = "PFG-Internet-Gateway" }
}

# Subred 1: Web (Apaches y HAProxy)
resource "aws_subnet" "subnet_dmz" {
  vpc_id            = aws_vpc.pfg_vpc.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet-Web" }
}

# Subred 2: Datos y Gestión (MariaDB y Zabbix)
resource "aws_subnet" "subnet_lan" {
  vpc_id            = aws_vpc.pfg_vpc.id
  cidr_block        = "192.168.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet-Datos-Gestion" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.pfg_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "Tabla-Enrutamiento-PFG" }
}

resource "aws_route_table_association" "assoc_dmz" {
  subnet_id      = aws_subnet.subnet_dmz.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_route_table_association" "assoc_lan" {
  subnet_id      = aws_subnet.subnet_lan.id
  route_table_id = aws_route_table.rt.id
}

# =================================================================
# 2. REGLAS DE FIREWALL (Security Group)
# =================================================================

resource "aws_security_group" "pfg_sg" {
  name        = "pfg-firewall"
  description = "Acceso SSH externo y comunicacion interna total"
  vpc_id      = aws_vpc.pfg_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "Firewall-PFG" }
}
resource "aws_key_pair" "deployer" {
  key_name   = "pfg-key-aws1"
  public_key = file("~/.ssh/pfg_key.pub")
}
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "cluster_dmz" {
  for_each               = var.vms_config_dmz
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"              # GRATIS
  subnet_id              = aws_subnet.subnet_dmz.id
  private_ip             = each.value
  vpc_security_group_ids = [aws_security_group.pfg_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = each.key
  }
  depends_on = [aws_route_table_association.assoc_dmz]
}
resource "aws_instance" "cluster_lan" {
  for_each               = var.vms_config_lan
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"              # GRATIS
  subnet_id              = aws_subnet.subnet_lan.id
  private_ip             = each.value
  vpc_security_group_ids = [aws_security_group.pfg_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name = each.key
  }
  depends_on = [aws_route_table_association.assoc_lan]
}

# =================================================================
# 4. LA MAGIA: GENERACIÓN AUTOMÁTICA DEL INVENTARIO DE ANSIBLE
# =================================================================

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/hosts"
  content  = <<EOT
    [db]
    mariadb-1 ansible_host=${aws_instance.cluster_lan["mariadb-1"].public_ip}
    mariadb-2 ansible_host=${aws_instance.cluster_lan["mariadb-2"].public_ip}

    [web]
    apache-1 ansible_host=${aws_instance.cluster_dmz["apache-1"].public_ip}
    apache-2 ansible_host=${aws_instance.cluster_dmz["apache-2"].public_ip}

    [proxy]
    haproxy-1 ansible_host=${aws_instance.cluster_dmz["haproxy-1"].public_ip}

    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_private_key_file=~/.ssh/pfg_key
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
}

# =================================================================
# 5. EL DISPARADOR: TERRAFORM LANZA ANSIBLE EN TU ORDENADOR
# =================================================================


resource "null_resource" "ejecutar_ansible" {
  # Asegura que Ansible no se lance hasta que las máquinas estén creadas
  depends_on = [aws_instance.cluster_dmz, aws_instance.cluster_lan]

  provisioner "local-exec" {
    command = <<EOT
      echo "Esperando 30 segundos a que el SSH de las instancias este listo..."
      sleep 30
      echo "Lanzando Ansible automaticamente..."
      ansible-playbook -i ./hosts site.yaml --private-key=~/.ssh/pfg_key
    EOT
  }
}

# =================================================================
# OUTPUTS
# =================================================================

output "IPs_Publicas_dmz" {
  value = { for k, v in aws_instance.cluster_dmz : k => v.public_ip }
  description = "IPs públicas de las instancias en la DMZ"

}
output "IPs_Publicas_lan" {
  value = { for k, v in aws_instance.cluster_lan : k => v.public_ip }
  description = "IPs públicas de las instancias en la LAN"
}