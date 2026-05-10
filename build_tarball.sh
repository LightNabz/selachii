#!/bin/bash
# 🦈 Selachii Linux — rootfs tarball builder
# Usage: ./build-tarball.sh [version] [rootfs_dir]
# Example: ./build-tarball.sh 26.0.0 ./rootfs

set -e

# --- config ---
VERSION="${1:-26.0.0}"
ROOTFS="${2:-./rootfs}"
ARCH="amd64"
OUTPUT="selachii-${VERSION}-${ARCH}.tar.xz"

# --- sanity checks ---
if [ ! -d "$ROOTFS" ]; then
  echo "❌ rootfs directory '$ROOTFS' not found"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ run this as root or with sudo"
  exit 1
fi

# warn if anything is still mounted inside rootfs
if grep -q "$ROOTFS" /proc/mounts; then
  echo "⚠️  WARNING: something is still mounted inside $ROOTFS"
  echo "   unmount first with: sudo umount -R $ROOTFS"
  grep "$ROOTFS" /proc/mounts
  exit 1
fi

echo "🦈 Building Selachii Linux $VERSION tarball..."
echo "   rootfs : $ROOTFS"
echo "   output : $OUTPUT"
echo ""

# --- tar it up ---
tar -cJpvf "$OUTPUT" \
  --xattrs-include='*.*' \
  --numeric-owner \
  --exclude='./proc/*' \
  --exclude='./sys/*' \
  --exclude='./dev/*' \
  --exclude='./run/*' \
  --exclude='./tmp/*' \
  --exclude='./boot/*' \
  --exclude='./mnt/*' \
  --exclude='./media/*' \
  -C "$ROOTFS" .

# --- done ---
echo ""
echo "✅ Done!"
echo "   $(du -sh "$OUTPUT" | cut -f1)  $OUTPUT"
echo ""
echo "📦 Upload to GitHub release with:"
echo "   gh release create v${VERSION} ${OUTPUT} --title \"Selachii Linux ${VERSION}\""
