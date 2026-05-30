# =================================================================
# 1. ASIGNACIÓN DE IP Y GATEWAY SEGÚN EL NOMBRE DE LA MÁQUINA
# =================================================================
HOSTNAME=$(hostname)
MI_IP=""
MI_GW=""

case "$HOSTNAME" in
  "mariadb-1")
    MI_IP="192.168.1.30"
    MI_GW="192.168.1.1"    # Gateway de la red 1
    ;;
  "mariadb-2")
    MI_IP="192.168.1.31"
    MI_GW="192.168.1.1"    # Gateway de la red 1
    ;;
  "apache-1")
    MI_IP="192.168.2.10"
    MI_GW="192.168.2.1"    # Gateway de la red 2
    ;;
  "apache-2")
    MI_IP="192.168.2.11"
    MI_GW="192.168.2.1"    # Gateway de la red 2
    ;;
  "haproxy-1")
    MI_IP="192.168.2.20"
    MI_GW="192.168.2.1"    # Gateway de la red 2
    ;;
  "zabbix")
    MI_IP="192.168.1.50"   # Si Zabbix va en la red 1
    MI_GW="192.168.1.1"
    ;;
esac

# Si ha reconocido la máquina, le aplicamos Netplan dinámicamente
if [ ! -z "$MI_IP" ]; then
  cat <<EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - ${MI_IP}/24
      gateway4: ${MI_GW}  # <-- ¡Aquí se mete la gateway correcta automáticamente!
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF
  # Aplicamos la nueva configuración de red en caliente
  netplan apply
  sleep 2
fi

# =================================================================
# 2. COMPROBACIÓN DE RED Y EJECUCIÓN DE ANSIBLE
# =================================================================
# Esperamos a que responda internet con la nueva IP instalada
until ping -c 1 github.com &>/dev/null; do sleep 3; done

# Clonamos tu repositorio de GitHub
cd /tmp
rm -rf config-repo
git clone https://github.com/garciaperezdavid211-max/pfg.git config-repo
cd config-repo/ansible/playbooks

# Lanzamos el Playbook que le toque a cada uno
case "$HOSTNAME" in
  "mariadb-1")
    ansible-playbook mariadb_setup.yaml -e "mysql_replication_role=master"
    ;;
  "mariadb-2")
    ansible-playbook mariadb_setup.yaml -e "mysql_replication_role=slave"
    ;;
  "apache-1" | "apache-2")
    ansible-playbook apache_setup.yaml
    ;;
  "haproxy-1")
    ansible-playbook haproxy_setup.yaml
    ;;
  "zabbix")
    ansible-playbook zabbix_setup.yaml
    ;;
esac

# Desactivamos el script para que no se vuelva a ejecutar en futuros reinicios
chmod -x /etc/rc.local

exit 0
