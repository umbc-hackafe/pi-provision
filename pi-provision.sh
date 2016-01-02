#!/bin/bash

set -e
set -u

function partition() {
    echo "$1" | grep 'mmcblk' > /dev/null 2>&1 && echo "$1p$2" && return
    echo "$1$2"
}

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <1|2> <device> <hostname>"
  exit 1
fi

VERSION="$1"
DEV="$2"
PIHOST="$3"

if [ "$VERSION" -ne "1" -a "$VERSION" -ne "2" ]; then
    echo "Invalid version $VERSION, please use 1 or 2."
    exit 1
fi

echo "o
p
n
p
1

+100M
t
c
n
p
2


w
" | fdisk $DEV

echo "Unmounting $(partition $DEV 1)..."
umount $(partition $DEV 1) || echo "Already unmounted."

mkfs.vfat $(partition $DEV 1)
mkdir -p boot
mount $(partition $DEV 1) boot

sleep 5
echo "Unmounting $(partition $DEV 2)..."
umount $(partition $DEV 2) || echo "Already unmounted."

mkfs.ext4 $(partition $DEV 2)
mkdir -p root
mount $(partition $DEV 2) root

if [ ! -f ArchLinuxARM-rpi-$VERSION-latest.tar.gz ]
then
    if [ "$VERSION" -eq "1" ]; then
	curl -LO http://archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz
	mv ArchLinuxARM-rpi-latest.tar.gz ArchLinuxARM-rpi-1-latest.tar.gz
    elif [ "$VERSION" -eq "2" -a ! -f ArchLinuxARM-rpi-2-latest.tar.gz ]
    then
        curl -LO http://archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
    fi
fi

bsdtar -xpf ArchLinuxARM-rpi-$VERSION-latest.tar.gz -C root
sync

mv root/boot/* boot

echo "$PIHOST" > root/etc/hostname

cat <<EOF | >> boot/config.txt

arm_freq=1000
core_freq=500
sdram_freq=500
over_voltage=6
gpu_mem_256=16
gpu_mem_512=16
EOF

umount boot root
sync
eject $DEV || true

echo "DONE -- Boot up Pi and connect to network"
echo "Waiting for SSH on $PIHOST..."


echo "Connecting... Please enter 'root':"
while true; do ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null root@$PIHOST 'pacman --noconfirm -Syu;pacman --noconfirm -S salt-zmq; systemctl start salt-minion' && break || sleep 30; done
