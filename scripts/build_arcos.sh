#!/bin/bash
set -e

echo "=== [ArcOS Engine] Starting V0.1-ALPHA Build for emerald ==="

WORK_DIR="/tmp/arcos_build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 1. Fetch the latest TrebleDroid Android 16 ARM64 GMS Release automatically
echo ">> Querying latest Android 16 GMS Treble image..."
GSI_URL=$(curl -s https://api.github.com/repos/TrebleDroid/treble_experimentations/releases | jq -r '.[0].assets[] | select(.name | test("arm64.*gapps.*img\\.xz$|arm64.*bgN.*img\\.xz$")) | .browser_download_url' | head -n 1)

# Fallback in case of rate limits or naming convention change
if [ -z "$GSI_URL" ] || [ "$GSI_URL" == "null" ]; then
    echo ">> Using primary A16 GMS Treble mirror..."
    GSI_URL="https://github.com/TrebleDroid/treble_experimentations/releases/download/ci-20250617/system-td-arm64-vanilla.img.xz"
fi

echo ">> Downloading base image from: $GSI_URL"
wget -O base_gsi.img.xz "$GSI_URL"

echo ">> Decompressing raw image..."
unxz -v base_gsi.img.xz

# Detect extracted file name
EXTRACTED_IMG=$(ls *.img | head -n 1)
mv "$EXTRACTED_IMG" system.raw.img

# 2. Expand filesystem slightly (+64MB) to ensure plenty of room for ArcOS props & modifications
echo ">> Expanding partition for ArcOS modifications..."
e2fsck -fy system.raw.img || true
resize2fs system.raw.img 4500M

# 3. Mount and inject ArcOS configurations for emerald
mkdir -p mnt
sudo mount -o loop,rw system.raw.img mnt

echo ">> Injecting ArcOS configs into build.prop..."
if [ -f "$GITHUB_WORKSPACE/configs/emerald.prop" ]; then
    sudo cat "$GITHUB_WORKSPACE/configs/emerald.prop" | sudo tee -a mnt/system/build.prop
    [ -f mnt/build.prop ] && sudo cat "$GITHUB_WORKSPACE/configs/emerald.prop" | sudo tee -a mnt/build.prop || true
fi

# Ensure DSU-specific runtime properties are present
echo "persist.sys.binary_xml=false" | sudo tee -a mnt/system/build.prop

# Unmount filesystem cleanly
sudo umount mnt
e2fsck -fy system.raw.img || true

# 4. Convert to Sparse Image and compress for DSU Sideloader
echo ">> Converting raw image to Android sparse format..."
img2simg system.raw.img ArcOS-V0.1-ALPHA-emerald.img

echo ">> Compressing output archive..."
gzip -c ArcOS-V0.1-ALPHA-emerald.img > "$GITHUB_WORKSPACE/ArcOS-V0.1-ALPHA-emerald.img.gz"

echo "=== [ArcOS Engine] Build Complete! ==="
