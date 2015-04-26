#!/bin/bash

set -e
set -u

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

echo "Unmounting ${DEV}1..."
umount ${DEV}1 || echo "Already unmounted."

mkfs.vfat ${DEV}1
mkdir -p boot
mount ${DEV}1 boot

sleep 5
echo "Unmounting ${DEV}2..."
umount ${DEV}2 || echo "Already unmounted."

mkfs.ext4 ${DEV}2
mkdir -p root
mount ${DEV}2 root

if [ ! -f ArchLinuxARM-rpi-$VERSION-latest.tar.gz ]
then
    if [ "$VERSION" -eq "1" ]; then
	wget http://archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz
	mv ArchLinuxARM-rpi-latest.tar.gz ArchLinuxARM-rpi-1-latest.tar.gz
    elif [ "$VERSION" -eq "2" -a ! -f ArchLinuxARM-rpi-2-latest.tar.gz ]
    then
        wget http://archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
    fi
fi

bsdtar -xpf ArchLinuxARM-rpi-$VERSION-latest.tar.gz -C root
sync

mv root/boot/* boot

echo "$PIHOST" > root/etc/hostname

umount boot root
sync
eject $DEV

echo "DONE -- Insert SD card"

while true; do ping -c 1 $PIHOST > /dev/null && break; sleep 5; done

echo "Prepare to run 'salt $PIHOST state.highstate'"

ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null root@$PIHOST 'pacman --noconfirm -Syu;pacman --noconfirm -S salt-zmq; salt-minion -l debug'
