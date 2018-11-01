#!/bin/bash


if [ $EUID != 0 ]; then
  sudo "$0" "$@"
  exit $?
fi


askFor () {
  if [[ "$arg1" == '-y' ]]; then
    return 0
  else
		echo "$1""? (y/n)"
		read x
		[[ "$x" == "y" ]]
	fi
}


# https://askubuntu.com/questions/1057458/how-to-remove-ubuntus-automatic-internet-connection-needs/1057463#1057463
if askFor "Disable updates"; then
	systemctl disable --now apt-daily{,-upgrade}.{timer,service}
	echo -e 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";' > /etc/apt/apt.conf.d/20auto-upgrades
fi


if askFor "Put /tmp on tmpfs"; then
	cp -v /usr/share/systemd/tmp.mount /etc/systemd/system/
	systemctl enable tmp.mount
fi


if askFor "Mount partitions with noatime" && (! grep -q  noatime /etc/fstab); then
  sed -i 's/ext4 */ext4    noatime,/g' /etc/fstab
fi


if askFor "Disable lvmetad" && (! grep -q  /dev/mapper /etc/fstab); then
  sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf
  systemctl disable --now lvm2-lvmetad{,socket}
fi


# grep . /sys/devices/system/cpu/vulnerabilities/*
if askFor "Disable Spectre, Meltdown, L1TF mitigation and NMI watchdog"; then
  sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="pti=off spectre_v2=off l1tf=off nospec_store_bypass_disable no_stf_barrier nmi_watchdog=0"/g' /etc/default/grub
  update-grub
fi


if askFor "Set vm.swappiness to 10"; then
  echo vm.swappiness=10 > /etc/sysctl.d/60-swappiness.conf
fi


if askFor "Disable  floppy disk drive?"; then
  echo "blacklist floppy" > /etc/modprobe.d/blacklist-floppy.conf
fi


if askFor "Remove some packages (please see source of this script)"; then
	apt update

	# optimize VM guests
	if [ "$(systemd-detect-virt)" = "vmware" ] && [ -z `which vmtoolsd` ]; then
		apt install -y open-vm-tools
	fi

	# remove really unnecassary (in my case) packages
	apt purge -y whoopsie libwhoopsie0
	apt purge -y bluez bluez-obexd blueman
	apt purge -y snapd gnome-software-plugin-snap squashfs-tools
	apt purge -y thunderbird\*
	apt purge -y open-iscsi lxcfs update-manager-core

	apt clean
fi


if askFor "reboot"; then
  /sbin/reboot
fi
