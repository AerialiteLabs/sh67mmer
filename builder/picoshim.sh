#!/bin/bash
# PicoShim Builder
# 2024

if [ $EUID -ne 0 ]; then
  echo "You MUST run this program with sudo or as root."
  exit 1
fi

if [ "$1" == "" ]; then
  echo "No shim passed, please pass a shim to the args."
  echo "$@"
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")
VERSION=1

HOST_ARCH=$(lscpu | grep Architecture | awk '{print $2}')
if [ $HOST_ARCH == "x86_64" ]; then
  CGPT="$SCRIPT_DIR/bins/cgpt.x86-64"
  SFDISK="$SCRIPT_DIR/bins/sfdisk.x86-64"
else
  CGPT="$SCRIPT_DIR/bins/cgpt.aarch64"
  SFDISK="$SCRIPT_DIR/bins/sfdisk.aarch64"
fi

source lib/extract_initramfs.sh
source lib/detect_arch.sh

echo "PicoShim builder"
echo "requires: binwalk, fdisk"

SHIM="$1"
initramfs="/tmp/initramfs_path"
ROOTFS_MNT="/tmp/picoshim_rootmnt"
loopdev=$(losetup -f)
STATE_SIZE=$((1 * 1024 * 1024)) 

rm -rf $initramfs # cleanup previous instances of picoshim, if they existed.
mkdir -p $initramfs

rm -rf $ROOTFS_MNT # cleanup previous instances of picoshim, if they existed.
mkdir -p $ROOTFS_MNT

if [ -f "$SHIM" ]; then
  losetup -P "$loopdev" "$SHIM"
else
  exit 1
fi

arch=$(detect_arch $loopdev)
extract_initramfs_full "$SHIM" "$initramfs" ""$loopdev"p2" "$arch"

echo "creating new filesystem on rootfs"
echo "y" | mkfs.ext4 "$loopdev"p3 -L ROOT-A
echo "mounting & moving files from initramfs to rootfs"
mount "$loopdev"p3 "$ROOTFS_MNT"
mv "$initramfs"/* "$ROOTFS_MNT"/
umount "$loopdev"p3

shrink_root 


echo "cleaning up"
losetup -D
rm -rf $initramfs
rm -rf $ROOTFS_MNT

