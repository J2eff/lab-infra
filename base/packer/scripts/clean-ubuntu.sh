#!/bin/bash

set -e

echo "=== Starting Ubuntu System Clean-up ==="

echo "Updating packages..."
apt-get -y update

echo "Cleaning up network settings..."
rm -rf /etc/netplan/00-installer-config.yaml

CLOUD_CFG_PATH="/etc/cloud/cloud.cfg"
BACKUP_PATH="/etc/cloud/cloud.cfg.bak"

echo "Backing up cloud.cfg..."
cp "$CLOUD_CFG_PATH" "$BACKUP_PATH"

echo "Configuring new cloud.cfg..."

tee "$CLOUD_CFG_PATH" > /dev/null <<EOF
users:
  - default

disable_root: true
preserve_hostname: false

cloud_init_modules:
  - seed_random
  - bootcmd
  - write_files
  - growpart
  - resizefs
  - disk_setup
  - mounts
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - ca_certs
  - rsyslog
  - users_groups
  - ssh
  - set_passwords

cloud_config_modules:
  - wireguard
  - snap
  - ubuntu_autoinstall
  - ssh_import_id
  - keyboard
  - locale
  - grub_dpkg
  - apt_pipelining
  - apt_configure
  - ubuntu_pro
  - ntp
  - timezone
  - disable_ec2_metadata
  - runcmd

cloud_final_modules:
  - package_update_upgrade_install
  - fan
  - landscape
  - lxd
  - ubuntu_drivers
  - write_files_deferred
  - puppet
  - chef
  - ansible
  - mcollective
  - salt_minion
  - reset_rmc
  - scripts_vendor
  - scripts_per_once
  - scripts_per_boot
  - scripts_per_instance
  - scripts_user
  - ssh_authkey_fingerprints
  - keys_to_console
  - install_hotplug
  - phone_home
  - final_message
  - power_state_change

system_info:
  distro: ubuntu
  default_user:
    name: ubuntu
    lock_passwd: True
    gecos: Ubuntu
    groups: [adm, audio, cdrom, dialout, dip, floppy, lxd, netdev, plugdev, sudo, video]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  network:
    dhcp_client_priority: [dhclient, dhcpcd, udhcpc]
    renderers: ['netplan', 'eni', 'sysconfig']
    activators: ['netplan', 'eni', 'network-manager', 'networkd']
  ntp_client: auto
  paths:
    cloud_dir: /var/lib/cloud/
    templates_dir: /etc/cloud/templates/
  package_mirrors:
    - arches: [amd64]
      failsafe:
        primary: http://archive.ubuntu.com/ubuntu/
        security: http://security.ubuntu.com/ubuntu/
      search:
        primary:
          - http://kr.archive.ubuntu.com/ubuntu/
          - http://archive.ubuntu.com/ubuntu/
        security:
          - http://security.ubuntu.com/ubuntu/
  ssh_svcname: ssh
EOF

echo "Successfully configured new cloud.cfg!"

# Complete cloud-init reset for fresh initialization
echo "Performing complete cloud-init reset..."
cloud-init clean --logs --seed 2>/dev/null || true
rm -rf /var/lib/cloud/instances/* 2>/dev/null || true
rm -rf /var/lib/cloud/sem/* 2>/dev/null || true
rm -rf /var/lib/cloud/data/* 2>/dev/null || true
rm -rf /var/log/cloud-init* 2>/dev/null || true

# Remove existing ubuntu user for fresh creation
echo "Removing existing ubuntu user for fresh initialization..."
userdel -r ubuntu 2>/dev/null || true

# Remove SSH keys for fresh generation
echo "Cleaning SSH host keys..."
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

# Reset machine ID for unique instance identification
echo "Resetting machine ID..."
truncate -s 0 /etc/machine-id 2>/dev/null || true
[ -f /var/lib/dbus/machine-id ] && rm -f /var/lib/dbus/machine-id 2>/dev/null || true

# Clean history and temporary files
echo "Cleaning user history and temporary files..."
rm -f /root/.bash_history 2>/dev/null || true
find /home -name ".bash_history" -delete 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/tmp/* 2>/dev/null || true

echo "=== Ubuntu System Clean-up Completed ==="
echo "System is ready for image creation - cloud-init will reinitialize on first boot"