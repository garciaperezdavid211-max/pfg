variable "aws_region" {
  type        = string
  default     = "eu-west-1"
  description = "Región de AWS donde se desplegará el clúster"
}

variable "vms_config_dmz" {
  type = map(string)
  default = {
    "apache-1"  = "192.168.2.10"
    "apache-2"  = "192.168.2.11"
    "haproxy-1" = "192.168.2.20"
  }
  description = "Mapeo de los nombres de las instancias y sus IPs privadas estáticas"
}
variable "vms_config_lan" {
  type = map(string)
  default = {
    "mariadb-1" = "192.168.1.30"
    "mariadb-2" = "192.168.1.31"
  }
  description = "Mapeo de los nombres de las instancias y sus IPs privadas estáticas"
}
variable "aws_access_key" {
  type        = string
  description = "Clave de acceso de AWS"
}
variable "aws_secret_key" {
  type        = string
  description = "Clave secreta de AWS"
}