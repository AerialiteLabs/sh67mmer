#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
REPO_DIR="vboot_reference"
BRANCH="release-R133-16151.B"

echo "This script was made to work with Ubuntu 22.04."
echo "By pressing ENTER, you acknowledge this"
echo "By pressing CTRL-C, you will deny this"
read -r

sudo apt install -y git wget libuuid1

if [[ ! -d "$SCRIPT_DIR/$REPO_DIR" ]]; then
    git clone https://chromium.googlesource.com/chromiumos/platform/vboot_reference -b "$BRANCH" "$SCRIPT_DIR/$REPO_DIR"
else
    echo "Repository already exists. Skipping clone."
fi


cd "$SCRIPT_DIR/$REPO_DIR" || exit 1
git apply ../vboot_reference.patch
CFLAGS="-fPIC" CXXFLAGS="-fPIC" make STATIC=1 TPM2_MODE=1 USE_FLASHROM=0

echo "Would you like to clean up the directory?"
read -rep "[Y/n] " cleanupChoice

if [[ "$cleanupChoice" == "y" || "$cleanupChoice" == "Y" || "$cleanupChoice" == "" ]]; then
    if [[ -d "$SCRIPT_DIR/build" ]]; then
	rm -rf "$SCRIPT_DIR/build"
    fi
    if [[ -d "$SCRIPT_DIR/$REPO_DIR/build" ]]; then
        mv "$SCRIPT_DIR/$REPO_DIR/build" "$SCRIPT_DIR"
    fi

    find "$SCRIPT_DIR/build" -name '*.o*' -type f -delete
    find "$SCRIPT_DIR/build" -type d -empty -delete
    rm -rf "$SCRIPT_DIR/$REPO_DIR"
    echo "Cleaned! Final build files are at $SCRIPT_DIR/build"
fi

