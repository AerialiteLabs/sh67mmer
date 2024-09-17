#!/bin/bash
# Code was borrowed from the SH1mmer repo, credits to them
# https://github.com/MercuryWorkshop/sh1mmer

get_sector_size() {
	"$SFDISK" -l "$1" | grep "Sector size" | awk '{print $4}'
}

get_final_sector() {
	"$SFDISK" -l -o end "$1" | grep "^\s*[0-9]" | awk '{print $1}' | sort -nr | head -n 1
}

# create_stateful(){
#   local final_sector=$(get_final_sector "$loopdev")
#   local sector_size=$(get_sector_size "$loopdev")
#   # special UUID is from grunt shim, dunno if this is different on other shims
#   "$CGPT" add "$loopdev" -i 1 -b $((final_sector + 1)) -s $((state_size / sector_size)) -t "9CC433E4-52DB-1F45-A951-316373C30605"
#   partx -u -n 1 "$loopdev"
#   mkfs.ext4 -F "$loopdev"p1
#   sync
# }

create_stateful(){
	local image="$1"
	fdisk "$image" << EOF > /dev/null 2>&1
n
1

+${state_size}M
w
EOF
echo "y" | mkfs.ext4 "$image"p1 > /dev/null 2>&1
}

is_ext2() {
	local rootfs="$1"
	local offset="${2-0}"

	local sb_magic_offset=$((0x438))
	local sb_value=$(dd if="$rootfs" skip=$((offset + sb_magic_offset)) \
		count=2 bs=1 2>/dev/null)
	local expected_sb_value=$(printf '\123\357')
	if [ "$sb_value" = "$expected_sb_value" ]; then
		return 0
	fi
	return 1
}

enable_rw_mount() {
	local rootfs="$1"
	local offset="${2-0}"

	if ! is_ext2 "$rootfs" $offset; then
		echo "enable_rw_mount called on non-ext2 filesystem: $rootfs $offset" 1>&2
		return 1
	fi

	local ro_compat_offset=$((0x464 + 3))
	printf '\000' |
		dd of="$rootfs" seek=$((offset + ro_compat_offset)) \
			conv=notrunc count=1 bs=1 2>/dev/null
}

disable_rw_mount() {
	local rootfs="$1"
	local offset="${2-0}"

	if ! is_ext2 "$rootfs" $offset; then
		echo "disable_rw_mount called on non-ext2 filesystem: $rootfs $offset" 1>&2
		return 1
	fi

	local ro_compat_offset=$((0x464 + 3))
	printf '\377' |
		dd of="$rootfs" seek=$((offset + ro_compat_offset)) \
			conv=notrunc count=1 bs=1 2>/dev/null
}

shrink_partitions() {
  local shim="$1"
  fdisk "$shim" <<EOF > /dev/null 2>&1
  d
  12
  d
  11
  d
  10
  d
  9
  d
  8
  d
  7
  d
  6
  d
  5
  d
  4
  d
  1
  w
EOF
}

truncate_image() {
	local buffer=35
	local sector_size=$("$SFDISK" -l "$1" | grep "Sector size" | awk '{print $4}')
	local final_sector=$(get_final_sector "$1")
	local end_bytes=$(((final_sector + buffer) * sector_size))

	echo "Truncating image to $(format_bytes "$end_bytes")"
	truncate -s "$end_bytes" "$1" > /dev/null 2>&1

	# recreate backup gpt table/header
	sgdisk -e "$1" 2>&1 | sed 's/\a//g' > /dev/null 2>&1
}

format_bytes() {
	numfmt --to=iec-i --suffix=B "$@"
}

shrink_root() {
    loopdev="$@"
    echo "$@"
    echo "$1"
    echo "Shrinking ROOT-A Partition"

    echo $loopdev

	enable_rw_mount "${loopdev}p3"
	e2fsck -fy "${loopdev}p3"
	resize2fs -M "${loopdev}p3"
	disable_rw_mount "${loopdev}p3"

	local sector_size=$(get_sector_size "$loopdev")
	local block_size=$(tune2fs -l "${loopdev}p3" | grep "Block size" | awk '{print $3}')
	local block_count=$(tune2fs -l "${loopdev}p3" | grep "Block count" | awk '{print $3}')

	local original_sectors=$("$CGPT" show -i 3 -s -n -q "$loopdev")
	local original_bytes=$((original_sectors * sector_size))

	local resized_bytes=$((block_count * block_size))
	local resized_sectors=$((resized_bytes / sector_size))

	echo "Resizing ROOT from $(format_bytes ${original_bytes}) to $(format_bytes ${resized_bytes})"
	"$CGPT" add -i 3 -s "$resized_sectors" "$loopdev"
	partx -u -n 3 "$loopdev"
}