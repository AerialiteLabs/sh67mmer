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

ARCHITECTURE="$(uname -m)"
case "$ARCHITECTURE" in
	*x86_64* | *x86-64*) ARCHITECTURE=x86_64 ;;
	*aarch64* | *armv8*) ARCHITECTURE=aarch64 ;;
	*i[3-6]86*) ARCHITECTURE=i386 ;;
	*) fail "Unsupported architecture $ARCHITECTURE" ;;
esac

source ${SCRIPT_DIR}/lib/extract_initramfs.sh
source ${SCRIPT_DIR}/lib/detect_arch.sh
source ${SCRIPT_DIR}/lib/rootfs_utils.sh

echo "PicoShim builder"
echo "requires: binwalk, fdisk, cgpt, mkfs.ext2, numfmt"

SHIM="$1"
initramfs="/tmp/initramfs_path"
rootfs_mnt="/tmp/picoshim_rootmnt"
loopdev=$(losetup -f)
CGPT="${SCRIPT_DIR}/lib/bin/$ARCHITECTURE/cgpt"
SFDISK="${SCRIPT_DIR}/lib/bin/$ARCHITECTURE/sfdisk"

# gets the initramfs size, e.g: 6.5M, and rounds it to the nearest whole number, e.g: 7M
# we're giving it 5 extra MBs to allow the busybox binaries to be installed
initramfs_size=$(($(du -sb "$initramfs" | awk '{print $1}' | numfmt --to=iec | awk '{print int($1) + ($1 > int($1))}') + 2))
kernsize=$(fdisk -l ${loopdev}p2 | head -n 1 | awk '{printf $3}')

# size of stateful partition in MiB
state_size="1"



rm -rf $initramfs # cleanup previous instances of picoshim, if they existed.
mkdir -p $initramfs

rm -rf $rootfs_mnt # cleanup previous instances of picoshim, if they existed.
mkdir -p $rootfs_mnt

if [ -f "$SHIM" ]; then
  shrink_partitions "$SHIM"
  losetup -P "$loopdev" "$SHIM"
else
  exit 1
fi

arch=$(detect_arch $loopdev)
extract_initramfs_full "$loopdev" "$initramfs" "/tmp/shim_kernel/kernel.img" "$arch"
dd if="${loopdev}p2" of=/tmp/kernel-new.bin bs=1M oflag=direct status=none

fdisk "$loopdev" <<EOF > /dev/null 2>&1
d
3
p
d
2
p
n
3

+${initramfs_size}M
n
2

+${kernsize}M
p

w
EOF
dd if=/tmp/kernel-new.bin of="${loopdev}p2" bs=1M oflag=direct status=none

echo "creating new filesystem on rootfs"
echo "y" | mkfs.ext2 "$loopdev"p3 -L ROOT-A > /dev/null 2>&1
echo "mounting & moving files from initramfs to rootfs"
mount "$loopdev"p3 "$rootfs_mnt"
mv "$initramfs"/* "$rootfs_mnt"/

create_stateful "$loopdev"


echo "adding kernel priorities"
"$CGPT" add "$loopdev" -i 2 -t kernel -P 1
"$CGPT" add "$loopdev" -i 3 -t rootfs

echo "cleaning up"
losetup -D

truncate_image "$SHIM"


rm -rf $initramfs
rm -rf $rootfs_mnt
umount "$loopdev"p3

