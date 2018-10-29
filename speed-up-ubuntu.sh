#!/bin/bash
# Run ./speed-up-ubuntu.sh --remove-some-packages


if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi


# Disable updates
# https://askubuntu.com/questions/1057458/how-to-remove-ubuntus-automatic-internet-connection-needs/1057463#1057463
systemctl disable --now apt-daily{,-upgrade}.{timer,service}
echo -e 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";' > /etc/apt/apt.conf.d/20auto-upgrades


# Put /tmp on tmpfs
cp -v /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount


#  Mounting partitions with noatime
if ! grep -q  noatime /etc/fstab; then
	sed -i 's/ext4 */ext4    noatime,/g' /etc/fstab
fi


# Disable lvmetad 
if ! grep -q  /dev/mapper /etc/fstab; then
	sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf
	systemctl disable --now lvm2-lvmetad{,socket}
fi 


# Disable Spectre, Meltdown, L1TF mitigation. Disable NMI watchdog.
# grep . /sys/devices/system/cpu/vulnerabilities/*
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="pti=off spectre_v2=off l1tf=off nospec_store_bypass_disable no_stf_barrier nmi_watchdog=0"/g' /etc/default/grub
update-grub


# configure vm.swappiness
echo vm.swappiness=10 > /etc/sysctl.d/60-swappiness.conf

# i'm pretty sure nobody uses floppy nowadays
echo "blacklist floppy" > /etc/modprobe.d/blacklist-floppy.conf

if [ "$1" == "--remove-some-packages" ]; then
	apt update

	# optimize VM guests
	if [ "$(systemd-detect-virt)" = "vmware" ] && [ -z `which vmtoolsd` ]; then
		apt install -y open-vm-tools
	fi
	# if [ "$(systemd-detect-virt)" = "kvm" ]; then
	# 	apt install -y linux-kvm
	# fi


	# remove really unnecassary (in my case) packages
	apt purge -y whoopsie libwhoopsie0
	apt purge -y bluez bluez-obexd blueman
	apt purge -y snapd gnome-software-plugin-snap squashfs-tools
	apt purge -y thunderbird\*
	apt purge -y open-iscsi lxcfs update-manager-core

	apt clean
fi

echo 'Reboot? (y/n)' && read x && [[ "$x" == "y" ]] && /sbin/reboot