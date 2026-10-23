#!/bin/bash
set -e

echo "=== [ArcOS Engine] Starting V0.1-ALPHA Build for emerald ==="

WORK_DIR="/tmp/arcos_build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 1. Fetch latest upstream Treble GSI image
echo ">> Querying latest Android 16 GMS Treble image..."
GSI_URL=$(curl -s https://api.github.com/repos/TrebleDroid/treble_experimentations/releases | jq -r '.[0].assets[] | select(.name | test("arm64.*gapps.*img\\.xz$|arm64.*bgN.*img\\.xz$")) | .browser_download_url' | head -n 1)

if [ -z "$GSI_URL" ] || [ "$GSI_URL" == "null" ]; then
    echo ">> Using primary fallback mirror..."
    GSI_URL="https://github.com/TrebleDroid/treble_experimentations/releases/download/ci-20250617/system-td-arm64-vanilla.img.xz"
fi

echo ">> Downloading: $GSI_URL"
wget -O base_gsi.img.xz "$GSI_URL"

echo ">> Extracting base image archive..."
unxz -v base_gsi.img.xz

EXTRACTED_FILE=$(ls *.img | head -n 1)

# Check if the extracted image is Android Sparse format; convert to raw if so
if file "$EXTRACTED_FILE" | grep -qi "sparse"; then
    echo ">> Converting sparse image to raw filesystem image..."
    simg2img "$EXTRACTED_FILE" system.raw.img
    rm -f "$EXTRACTED_FILE"
else
    mv "$EXTRACTED_FILE" system.raw.img
fi

# 2. Expand file container by +250MB, THEN expand the filesystem
echo ">> Expanding container file and filesystem..."
truncate -s +250M system.raw.img
e2fsck -fy system.raw.img || true
resize2fs system.raw.img

# 3. Mount partition cleanly
mkdir -p mnt
echo ">> Mounting system filesystem..."
sudo mount -t ext4 -o loop,rw system.raw.img mnt

# 4. Inject ArcOS emerald configurations into all build.prop instances (system, system_ext, etc.)
echo ">> Scanning and injecting ArcOS properties..."
find mnt -type f -name "build.prop" | while read -r prop_file; do
    echo ">> Injecting into: $prop_file"
    if [ -f "$GITHUB_WORKSPACE/configs/emerald.prop" ]; then
        sudo cat "$GITHUB_WORKSPACE/configs/emerald.prop" | sudo tee -a "$prop_file"
    fi
    echo "persist.sys.binary_xml=false" | sudo tee -a "$prop_file"
done

# Synchronize write operations & unmount
sync
sudo umount mnt
e2fsck -fy system.raw.img || true

# 5. Convert to Android Sparse format and compress
echo ">> Compressing to Android Sparse Image for DSU Sideloader..."
img2simg system.raw.img ArcOS-V0.1-ALPHA-emerald.img

gzip -c ArcOS-V0.1-ALPHA-emerald.img > "$GITHUB_WORKSPACE/ArcOS-V0.1-ALPHA-emerald.img.gz"

echo "=== [ArcOS Engine] Build Complete! ==="
