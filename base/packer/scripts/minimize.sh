#!/bin/bash

# Ubuntu image minimization script (final version)
set -e

echo "=== Starting Image Minimization ==="

# 1. Package cleanup
echo "Cleaning up packages..."
apt-get clean
apt-get autoclean  
apt-get autoremove -y --purge

# 2. Complete APT cache deletion
echo "Removing APT cache..."
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/cache/apt/archives/partial/*
rm -rf /var/cache/debconf/*

# 3. Temporary files cleanup
echo "Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /var/crash/*
rm -rf /var/backups/*

# 4. Log files cleanup
echo "Cleaning log files..."
find /var/log -type f -name "*.log" -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
find /var/log -type f -name "*.1" -delete 2>/dev/null || true
find /var/log -type f -name "*.old" -delete 2>/dev/null || true
> /var/log/wtmp
> /var/log/btmp
> /var/log/lastlog
truncate -s 0 /var/log/auth.log 2>/dev/null || true
truncate -s 0 /var/log/syslog 2>/dev/null || true

# 5. systemd journal cleanup
echo "Cleaning journal files..."
journalctl --vacuum-time=1d 2>/dev/null || true
journalctl --vacuum-size=10M 2>/dev/null || true

# 6. Old kernel cleanup (keep only current kernel)
echo "Removing old kernels..."
CURRENT_KERNEL=$(uname -r)
dpkg -l 2>/dev/null | grep linux-image | grep -v $CURRENT_KERNEL | awk '{print $2}' | xargs apt-get -y purge 2>/dev/null || true
dpkg -l 2>/dev/null | grep linux-headers | grep -v $CURRENT_KERNEL | awk '{print $2}' | xargs apt-get -y purge 2>/dev/null || true

# 7. Remove unnecessary packages
echo "Removing unnecessary packages..."
PACKAGES_TO_REMOVE="popularity-contest installation-report landscape-common wireless-tools wpasupplicant ubuntu-serverguide"
for pkg in $PACKAGES_TO_REMOVE; do
    apt-get purge -y $pkg 2>/dev/null || true
done

# Additional unnecessary packages
apt-get purge -y apport* 2>/dev/null || true
apt-get purge -y cups* 2>/dev/null || true  
apt-get purge -y reportbug 2>/dev/null || true
apt-get purge -y speak 2>/dev/null || true
apt-get purge -y sound* 2>/dev/null || true
apt-get purge -y alsa* 2>/dev/null || true
apt-get purge -y pulseaudio* 2>/dev/null || true

# 8. Clean empty directories
echo "Removing empty directories..."
find /usr -type d -empty -delete 2>/dev/null || true
find /var -type d -empty -delete 2>/dev/null || true

# 9. History file cleanup
echo "Cleaning history files..."
rm -f /root/.bash_history
find /home -name ".bash_history" -delete 2>/dev/null || true
history -c 2>/dev/null || true

# 10. Remove SSH host keys (will be regenerated on first boot)
echo "Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

# 11. Network interface information cleanup
echo "Cleaning network configuration..."
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules

# 12. Disk space zero-fill - CRITICAL for compression!
echo "Performing disk zero-fill... (Essential for compression improvement)"
echo "This may take some time. Please wait..."

# Zero-fill root partition
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY

# Zero-fill swap partition if exists
if swapon -s | grep -q partition 2>/dev/null; then
    echo "Zero-filling swap partition..."
    SWAP_PARTITION=$(swapon -s | grep partition | awk '{print $1}')
    swapoff $SWAP_PARTITION
    dd if=/dev/zero of=$SWAP_PARTITION bs=1M 2>/dev/null || true
    mkswap $SWAP_PARTITION
fi

# 13. Final cleanup
echo "Performing final cleanup..."
sync

echo "=== Image Minimization Completed ==="

# Display final status
echo ""
echo "Disk usage:"
df -h / 2>/dev/null || true

echo ""
echo "Number of installed packages:"
dpkg -l 2>/dev/null | grep -c ^ii || echo "Failed to count packages"

echo ""
echo "Minimization process completed successfully!"
echo "The qcow2 image size should now be significantly reduced."