#!/bin/bash
set -e

echo "=== [ArcOS Engine] Starting V0.1-ALPHA Build for emerald ==="

WORK_DIR="/tmp/arcos_build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 1. Download base A16 ARM64 GMS upstream image
echo ">> Downloading AOSP 16 GMS Base Image..."
wget -q -O base_gsi.img.xz "https://github.com/phhusson/treble_experimentations/releases/download/v2024.01/system-squeak-arm64-bgN.img.xz" || \
wget -q -O base_gsi.img.xz "https://android.googlesource.com/+archive/refs/heads/master.tar.gz"

echo ">> Extracting compressed image..."
xz -d base_gsi.img.xz || true

# Rename to standard file name
if [ -f base_gsi.img ]; then
    mv base_gsi.img system.raw.img
fi

# 2. Mount and patch the system partition
mkdir -p mnt
echo ">> Mounting system filesystem..."
sudo mount -o loop,rw system.raw.img mnt

echo ">> Injecting ArcOS Configurations & emerald Overlays..."
if [ -f "$GITHUB_WORKSPACE/configs/emerald.prop" ]; then
    sudo cat "$GITHUB_WORKSPACE/configs/emerald.prop" | sudo tee -a mnt/system/build.prop
    sudo cat "$GITHUB_WORKSPACE/configs/emerald.prop" | sudo tee -a mnt/build.prop || true
fi

# Ensure DSU compatibility properties
echo "persist.sys.binary_xml=false" | sudo tee -a mnt/system/build.prop
echo "ro.system.build.version.release=16" | sudo tee -a mnt/system/build.prop

# 3. Unmount and package
echo ">> Finalizing system image..."
sudo umount mnt

# Convert to Android Sparse Image for fast loading and low file size
img2simg system.raw.img ArcOS-V0.1-ALPHA-emerald.img
gzip -c ArcOS-V0.1-ALPHA-emerald.img > "$GITHUB_WORKSPACE/ArcOS-V0.1-ALPHA-emerald.img.gz"

echo "=== [ArcOS Engine] Image packaged successfully! ==="
