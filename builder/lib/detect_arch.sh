detect_arch() {
	LOOPDEV="$1"
	MNT_ROOT=$(mktemp -d)
	mount -o ro "${LOOPDEV}p3" "$MNT_ROOT"

	TARGET_ARCH=x86_64
	if [ -f "$MNT_ROOT/bin/bash" ]; then
		case "$(file -b "$MNT_ROOT/bin/bash" | awk -F ', ' '{print $2}' | tr '[:upper:]' '[:lower:]')" in
			# for now assume arm has aarch64 kernel
			*aarch64* | *armv8* | *arm*) TARGET_ARCH=aarch64 ;;
		esac
	fi
	echo "$TARGET_ARCH"

	umount "$MNT_ROOT"
	rmdir "$MNT_ROOT"
}
