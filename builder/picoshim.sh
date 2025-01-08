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
SCRIPT_DIR=${SCRIPT_DIR:-"."}
VERSION=1

ARCHITECTURE="$(uname -m)"
case "$ARCHITECTURE" in
	*x86_64* | *x86-64*) ARCHITECTURE=x86_64 ;;
	*aarch64* | *armv8*) ARCHITECTURE=aarch64 ;;
	*) fail "Unsupported architecture $ARCHITECTURE" ;;
esac

source ${SCRIPT_DIR}/lib/extract_initramfs.sh
source ${SCRIPT_DIR}/lib/detect_arch.sh
source ${SCRIPT_DIR}/lib/rootfs_utils.sh

echo "PicoShim builder"
echo "requires: binwalk, fdisk, cgpt, mkfs.ext2, numfmt"

SHIM="$1"
initramfs="/tmp/picoshim_initramfs"
rootfs_mnt="/tmp/picoshim_rootfsmnt"
state_mnt="/tmp/picoshim_statemnt"
CGPT="${SCRIPT_DIR}/bins/$ARCHITECTURE/cgpt"
SFDISK="${SCRIPT_DIR}/bins/$ARCHITECTURE/sfdisk"

# size of stateful partition in MiB
state_size="1"


rm -rf /tmp/kernel*
losetup -D

rm -rf $initramfs # cleanup previous instances of picoshim, if they existed.
mkdir -p $initramfs

rm -rf $rootfs_mnt # cleanup previous instances of picoshim, if they existed.
mkdir -p $rootfs_mnt

rm -rf $state_mnt # cleanup previous instances of picoshim, if they existed.
mkdir -p $state_mnt

rm -rf /tmp/loop0

# the amount of headaches loop0 has caused me....
if ! $(losetup | grep loop0); then
	touch /tmp/loop0
	dd if=/dev/urandom of=/tmp/loop0 bs=1 count=512 status=none > /dev/null 2>&1
	losetup -P /dev/loop0 /tmp/loop0
fi

loopdev=$(losetup -f)

if [ -f "$SHIM" ]; then
  shrink_partitions "$SHIM"
  losetup -P "$loopdev" "$SHIM"
else
  exit 1
fi

arch=$(detect_arch $loopdev)
extract_initramfs_full "$loopdev" "$initramfs" "/tmp/shim_kernel/kernel.img" "$arch"
dd if="${loopdev}p2" of=/tmp/kernel-new.bin bs=1M status=none

# gets the initramfs size, e.g: 6.5M, and rounds it to the nearest whole number, e.g: 7M
# we're giving it 5 extra MBs to allow the busybox binaries to be installed & our bootstrapped stuff
initramfs_size=$(($(du -sb "$initramfs" | awk '{print $1}' | numfmt --to=iec | awk '{print int($1) + ($1 > int($1))}') + 3))
kernsize=$(($(du -sb /tmp/kernel-new.bin | awk '{print $1}' | numfmt --to=iec | awk '{print int($1) + ($1 > int($1))}')))
# add another meg to the kernel just incase of resigning issues (:spoob:)

echo "fdisk!"

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
dd if=/tmp/kernel-new.bin of="${loopdev}p2" bs=1M oflag=direct status=none conv=notrunc

echo "creating new filesystem on rootfs"
echo "y" | mkfs.ext2 "$loopdev"p3 -L ROOT-A > /dev/null 2>&1
echo "mounting & moving files from initramfs to rootfs"
mount "$loopdev"p3 "$rootfs_mnt"
mv "$initramfs"/* "$rootfs_mnt"/

echo "bootstrapping rootfs..." 
# we have to do this due to issues with the `cp` command
noarchfolders=$(ls "${SCRIPT_DIR}/bootstrap/noarch/")
for folder in $noarchfolders; do
  cp -r "${SCRIPT_DIR}/bootstrap/noarch/${folder}" "$rootfs_mnt"
done

archfolders=$(ls "${SCRIPT_DIR}/bootstrap/$arch/")
for folder in $archfolders; do 
  cp -r "${SCRIPT_DIR}/bootstrap/${arch}/${folder}" "$rootfs_mnt"
done

printf "#!/bin/busybox sh \n /bin/busybox --install /bin" > "$rootfs_mnt"/installbins
chmod +x "$rootfs_mnt"/installbins
chroot "$rootfs_mnt" "/installbins"

create_stateful "$loopdev"
mount "$loopdev"p1 "$state_mnt"
mkdir -p "$state_mnt"/dev_image/etc/
touch "$state_mnt"/dev_image/etc/lsb-factory


echo "adding kernel priorities"
"$CGPT" add "$loopdev" -i 2 -t kernel -P 15 -T 15 -S 1 -R 1 -l KERN-A
"$CGPT" add "$loopdev" -i 3 -t rootfs -l ROOT-A

echo "cleaning up"
losetup -D

truncate_image "$SHIM"

umount "$loopdev"p3
umount "$loopdev"p1
rm -rf $initramfs
rm -rf $rootfs_mnt
