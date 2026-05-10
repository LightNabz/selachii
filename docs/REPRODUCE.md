# Building a Minimal LFS Stage3-Style Tarball

A practical guide to trimming a completed Linux From Scratch (LFS) rootfs into a
distributable stage3 tarball — similar in spirit to a Gentoo Stage3 — while keeping
a fully functional compiler, Python, Perl, SSH, and Git.

**Reference build:**
- LFS 12.x / GCC 15.2.0 / glibc 2.43 / Python 3.14 / OpenRC
- Before: ~900MB compressed tarball
- After: ~248MB compressed (without Git), ~310MB (with Git)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Audit Before You Touch Anything](#audit-before-you-touch-anything)
3. [Pass 1 — Cross-Compiler Removal (Inside Chroot)](#pass-1--cross-compiler-removal-inside-chroot)
4. [Pass 2 — Stripping and Bulk Cleanup (Outside Chroot)](#pass-2--stripping-and-bulk-cleanup-outside-chroot)
5. [Pass 2b — Locale Rebuild (Inside Chroot)](#pass-2b--locale-rebuild-inside-chroot)
6. [Pre-Pack Checklist](#pre-pack-checklist)
7. [Testing](#testing)
8. [Packing](#packing)
9. [First Boot Instructions for Deployers](#first-boot-instructions-for-deployers)
10. [Lessons Learned / Pitfalls](#lessons-learned--pitfalls)

---

## Prerequisites

- A completed LFS build mounted or accessible as a rootfs directory (e.g. `./rootfs`)
- Host system with `tar`, `strip`, `file`, `stat`, `find`
- Root access on the host
- The original LFS tarball kept somewhere safe for emergency restores

---

## Audit Before You Touch Anything

**Never remove anything without auditing first.** Run this entire block and save the output.

```bash
# Triplet info — critical: tells you which libexec dir to KEEP
gcc -dumpmachine
gcc -v 2>&1 | grep -E '(Target|Configured|gcc version)'

# GCC runtime search paths
gcc -print-search-dirs

# Check for any hardcoded lfs paths in specs
gcc -dumpspecs 2>&1 | grep -E '(lfs|sysroot|libexec)'

# What cc1 and friends exist
find /usr/libexec/gcc -type f | sort
find /usr/lib/gcc -type f | sort
find /usr/lib/gcc -type l | sort
find /usr/libexec/gcc -type l | sort

# Sysroot stub
ls -la /usr/x86_64-lfs-linux-gnu/ 2>/dev/null || echo "not present"

# Static libs
ls -lh /usr/lib/lib*.a 2>/dev/null

# Overall size breakdown
du -sh /usr/* | sort -rh
du -sh /usr/lib/* | sort -rh
du -sh /usr/libexec/gcc/*/* | sort -rh
```

### What to look for

The most important output is `gcc -dumpmachine`. It tells you which triplet directory
your **native** compiler lives under. In a standard LFS build you will see one of:

- `x86_64-pc-linux-gnu` — your **final native** compiler; **keep** this tree
- `x86_64-lfs-linux-gnu` — the **cross-compiler** used during LFS build phases; **remove** this tree

The two trees exist under both `/usr/libexec/gcc/` and `/usr/lib/gcc/`. Always verify
with `gcc -print-search-dirs` that the native compiler does not reference the lfs triplet
at runtime before removing anything.

---

## Pass 1 — Cross-Compiler Removal (Inside Chroot)

Run inside the chroot. This is the single biggest win — typically ~1.1G saved.

```bash
#!/bin/bash
set -euo pipefail
echo "=== Pass 1: Cross-Compiler Removal ==="

# Substitute your actual triplets if different
NATIVE="x86_64-pc-linux-gnu"
CROSS="x86_64-lfs-linux-gnu"
GCC_VER="15.2.0"   # adjust to match your build

echo "[1/4] Removing cross-compiler libexec tree..."
rm -rf /usr/libexec/gcc/$CROSS

echo "[2/4] Removing cross-compiler lib tree..."
rm -rf /usr/lib/gcc/$CROSS

echo "[3/4] Removing LFS sysroot stub..."
rm -rf /usr/$CROSS

echo "[4/4] Removing unused static libs..."
# Safe to remove: sanitizers, static C++ libs — not needed for kernel builds
# Keep: libc.a, libc_nonshared.a, libatomic.a, libssp_nonshared.a, libm.a
rm -f \
  /usr/lib/libstdc++.a \
  /usr/lib/libstdc++exp.a \
  /usr/lib/libstdc++fs.a \
  /usr/lib/libsupc++.a \
  /usr/lib/libasan.a \
  /usr/lib/libtsan.a \
  /usr/lib/libhwasan.a \
  /usr/lib/liblsan.a \
  /usr/lib/libubsan.a \
  /usr/lib/libm-*.a \
  /usr/lib/libmvec.a \
  /usr/lib/libgomp.a \
  /usr/lib/libitm.a \
  /usr/lib/libquadmath.a

echo "[5/4] Sanity check..."
echo 'int main(){return 0;}' > /tmp/t.c
gcc /tmp/t.c -o /tmp/t && echo "compiler ok" && rm /tmp/t /tmp/t.c

echo "=== Pass 1 done ==="
du -sh /usr/libexec/gcc /usr/lib/gcc /usr
```

### Static libs: what to keep vs remove

| Library | Safe to remove? | Reason |
|---|---|---|
| `libstdc++.a` | Yes | Dynamic `.so` stays; static C++ rarely needed |
| `libasan.a`, `libtsan.a`, `libhwasan.a`, `liblsan.a`, `libubsan.a` | Yes | Sanitizers, not needed for kernel builds |
| `libgomp.a` | Yes | OpenMP static, rarely needed |
| `libitm.a`, `libquadmath.a`, `libmvec.a` | Yes | Niche, safe to drop |
| `libm-X.Y.a` | Yes | Versioned copy; `libm.a` linker script stays |
| `libc.a` | **No** | GCC probes for it; removal can break configure scripts |
| `libc_nonshared.a` | **No** | Required for dynamic linking |
| `libatomic.a` | **No** | Kernel modules may need it |
| `libssp_nonshared.a` | **No** | Stack protector runtime stub |
| `libm.a` | **No** | Just a linker script, 98 bytes |
| `libgcc_s.so` | **No** | Linker script, not a real binary |

---

## Pass 2 — Stripping and Bulk Cleanup (Outside Chroot)

**Run from the host, outside the chroot.** Stripping shared libraries from inside a live
chroot causes Bus errors and Segfaults because the libraries are mapped into memory.
Doing it from outside is completely safe.

```bash
#!/bin/bash
set -euo pipefail
ROOTFS="./rootfs"   # adjust to your rootfs path
GCC_VER="15.2.0"
NATIVE="x86_64-pc-linux-gnu"

echo "=== Pass 2: Strip + Bulk Cleanup (Host Side) ==="

echo "[1/7] Stripping GCC compiler binaries..."
for f in cc1 cc1plus lto1 lto-wrapper collect2; do
    target="$ROOTFS/usr/libexec/gcc/$NATIVE/$GCC_VER/$f"
    strip --strip-debug "$target" && echo "  stripped: $f" || echo "  SKIP: $f"
done
du -sh "$ROOTFS/usr/libexec/gcc/"

echo "[2/7] Stripping ELF binaries in /usr/bin and /usr/sbin..."
find "$ROOTFS/usr/bin" "$ROOTFS/usr/sbin" -type f | while read -r f; do
    file "$f" 2>/dev/null | grep -q ELF \
      && strip --strip-debug "$f" 2>/dev/null \
      || true
done

echo "[3/7] Stripping shared libraries in /usr/lib..."
# NOTE: never strip .a static archives — strip corrupts them
find "$ROOTFS/usr/lib" -type f -name '*.so*' ! -name '*.a' | while read -r f; do
    file "$f" 2>/dev/null | grep -q ELF \
      && strip --strip-debug "$f" 2>/dev/null \
      || true
done

echo "[4/7] Removing Python test suite, idlelib, tkinter, turtle..."
rm -rf \
  "$ROOTFS/usr/lib/python3.14/test" \
  "$ROOTFS/usr/lib/python3.14/idlelib" \
  "$ROOTFS/usr/lib/python3.14/tkinter" \
  "$ROOTFS/usr/lib/python3.14/turtledemo" \
  "$ROOTFS/usr/lib/python3.14/turtle.py"

echo "[5/7] Removing Python __pycache__ and .pyc/.pyo files..."
find "$ROOTFS/usr/lib/python3.14" -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find "$ROOTFS/usr/lib/python3.14" \( -name '*.pyc' -o -name '*.pyo' \) -delete 2>/dev/null || true

echo "[6/7] Removing Perl pod and ph docs..."
find "$ROOTFS/usr/lib/perl5" -name '*.pod' -delete
find "$ROOTFS/usr/lib/perl5" -name '*.ph'  -delete 2>/dev/null || true

echo "[7/7] Removing /usr/share bulk..."
rm -rf \
  "$ROOTFS/usr/share/doc" \
  "$ROOTFS/usr/share/info" \
  "$ROOTFS/usr/share/locale" \
  "$ROOTFS/usr/share/i18n"

echo ""
echo "=== Pass 2 done. Sizes: ==="
du -sh \
  "$ROOTFS/usr/libexec/gcc" \
  "$ROOTFS/usr/lib/python3.14" \
  "$ROOTFS/usr/lib/locale" \
  "$ROOTFS/usr/share" \
  "$ROOTFS/usr"
```

### Corruption check after stripping

After stripping, verify no shared library was accidentally zeroed:

```bash
find ./rootfs/usr/lib -type f -name '*.so*' | while read -r f; do
    size=$(stat -c%s "$f")
    if [ "$size" -lt 4096 ]; then
        echo "SMALL ($size bytes): $f"
    fi
done
```

Files under 4096 bytes that are **expected** (linker scripts, not corruption):

- `libgcc_s.so` — linker script redirecting to the real `.so`
- `libm.so` — same
- `libc.so` — same

If you see a real shared library at 0 bytes (e.g. `libz.so.1.3.x: empty`), restore it
from the original tarball:

```bash
tar -xf ./release/your-original.tar.xz -C ./rootfs/ ./usr/lib/libz.so.1.3.2
```

---

## Pass 2b — Locale Rebuild (Inside Chroot)

The locale archive must be rebuilt from **inside** the chroot, because `localedef` needs
to write the archive in the format matching the rootfs's glibc version.

**Important:** Pass 2 deletes `/usr/share/i18n` which `localedef` needs. If you ran
Pass 2 already, restore it first:

```bash
# From host — restore only i18n from original tarball
tar -xf ./release/your-original.tar.xz -C ./rootfs/ ./usr/share/i18n
```

Then enter the chroot and rebuild:

```bash
#!/bin/bash
set -euo pipefail
echo "=== Pass 2b: Locale Rebuild (Chroot Side) ==="

echo "[1/2] Rebuilding minimal locale-archive..."
rm -f /usr/lib/locale/locale-archive
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i POSIX -f UTF-8 C.UTF-8 2>/dev/null || true
du -sh /usr/lib/locale/

echo "[2/2] Deleting /usr/share/i18n now that locale is rebuilt..."
rm -rf /usr/share/i18n

echo "=== Pass 2b done ==="
```

Add more locales before deleting i18n if your target audience needs them.

---

## Pre-Pack Checklist

Run inside the chroot before unmounting and packing.

```bash
# 1. Lock root password (empty password must never ship)
passwd -l root
grep root /etc/shadow   # should show root:!: not root::

# 2. Remove SSH host keys (regenerated on first boot)
rm -f /etc/ssh/ssh_host_*
ls /etc/ssh/   # should show only ssh_config and sshd_config

# 3. Genericize fstab (machine-specific partition layout must not ship)
cat > /etc/fstab << 'EOF'
# Begin /etc/fstab
# Configure this for your system before first boot
# Example:
# /dev/sda1     /       ext4    defaults    1 1
# /dev/sda2     none    swap    sw          0 0
# End /etc/fstab
EOF

# 4. Generic hostname
echo "localhost" > /etc/hostname

# 5. Clear logs
truncate -s 0 /var/log/btmp
truncate -s 0 /var/log/dmesg
truncate -s 0 /var/log/faillog
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp

# 6. Clear shell history
rm -f /root/.bash_history /root/.ash_history

# 7. Create empty machine-id (populated on first boot)
touch /etc/machine-id

# 8. Verify mtab is a symlink (not a real file)
ls -la /etc/mtab
# Expected: /etc/mtab -> /proc/self/mounts

# 9. Verify no leftover build sources or scripts
ls /root/
ls /tmp/
ls /var/tmp/
ls /sources/ 2>/dev/null || echo "no /sources (good)"
```

---

## Testing

Run this inside the chroot before packing. All tests must pass.

```bash
#!/bin/bash
echo "=== Toolchain Tests ==="

echo '#include <stdio.h>
int main(){ printf("C ok\n"); return 0; }' > /tmp/t.c
gcc /tmp/t.c -o /tmp/t && /tmp/t

echo '#include <stdio.h>
#include <math.h>
int main(){ printf("%.4f\n", __builtin_sqrt(2.0)); return 0; }' > /tmp/t.c
gcc /tmp/t.c -o /tmp/t -lm && /tmp/t

echo '#include <iostream>
#include <vector>
int main(){ std::vector<int> v={1,2,3}; for(auto x:v) std::cout<<x<<" "; std::cout<<std::endl; }' > /tmp/t.cpp
g++ -std=c++17 /tmp/t.cpp -o /tmp/t && /tmp/t

gcc -static /tmp/t.c -o /tmp/t && file /tmp/t | grep -o 'statically linked'
gcc -flto   /tmp/t.c -o /tmp/t && echo "LTO ok"

echo ""
echo "=== Python ==="
python3 -c "import os, sys, json, ssl, sqlite3; print('stdlib ok')"

echo ""
echo "=== Perl ==="
perl -MPOSIX -e 'print "perl ok\n"'

echo ""
echo "=== Core Tools ==="
gcc --version | head -1
make --version | head -1
ld --version | head -1

echo ""
echo "=== Kernel Build Deps ==="
for cmd in gcc g++ make ld bc flex bison perl python3; do
    type "$cmd" &>/dev/null && echo "  OK: $cmd" || echo "  MISSING: $cmd"
done

rm -f /tmp/t /tmp/t.c /tmp/t.cpp
echo ""
echo "=== All tests done ==="
```

`bc`, `flex`, and `bison` are required by the Linux kernel build system. If any show
as MISSING, install them before packing.

---

## Packing

```bash
# 1. Exit the chroot
exit

# 2. Unmount everything — REQUIRED before packing
umount ./rootfs/dev/pts
umount ./rootfs/dev
umount ./rootfs/proc
umount ./rootfs/sys
umount ./rootfs/run

# If any are busy, use lazy unmount
# umount -l ./rootfs/dev/pts  etc.

# 3. Verify nothing is left mounted
mount | grep rootfs
# Must return empty

# 4. Pack
cd ./rootfs
tar --zstd \
    --numeric-owner \
    --xattrs \
    --acls \
    -cpf ../lfs-stage3-amd64-$(date +%Y%m%d).tar.zst \
    .

# 5. Check final size
ls -lh ../lfs-stage3-amd64-*.tar.zst
```

`--numeric-owner` preserves uid/gid numerically, avoiding dependency on the host's
`/etc/passwd`. `--zstd` gives better compression than gzip with fast decompression,
matching modern Gentoo stage3 format. Use `-J` instead of `--zstd` for xz if you
prefer maximum compression at the cost of slower pack time.

---

## First Boot Instructions for Deployers

Anyone deploying this stage3 should do the following immediately after extraction:

```bash
# 1. Set root password
passwd root

# 2. Regenerate SSH host keys
ssh-keygen -A

# 3. Configure /etc/fstab for your partition layout

# 4. Set hostname
echo "yourhostname" > /etc/hostname

# 5. Configure /etc/resolv.conf for DNS

# 6. Add any additional locales if needed
# (requires reinstalling glibc locale data or using a pre-built locale-archive)
```

---

## Lessons Learned / Pitfalls

### 1. Know your triplet before removing anything

`gcc -dumpmachine` tells you which libexec tree your native compiler uses. In LFS,
the **final** GCC is often configured with `x86_64-lfs-linux-gnu` as its host triplet
even though the cross-compiler pass used `x86_64-pc-linux-gnu`. Always verify before
assuming which directory to remove.

### 2. Never strip shared libraries from inside a live chroot

Stripping `.so` files that are currently mapped into memory by the running shell or
dynamic linker causes Bus errors and Segfaults. Always strip from outside the chroot
where nothing in the rootfs is loaded.

### 3. Never strip `.a` static archives

`strip` corrupts static archives. Always exclude `*.a` files from strip operations:

```bash
find ... ! -name '*.a' | while read -r f; do
    file "$f" | grep -q ELF && strip --strip-debug "$f" || true
done
```

### 4. Rebuild locale before deleting `/usr/share/i18n`

`localedef` reads character map data from `/usr/share/i18n/charmaps/` to build the
locale archive. If you delete `/usr/share/i18n` before running `localedef`, the rebuild
fails. Always: rebuild locale → then delete i18n.

### 5. Stripping can zero out small shared libraries

`strip` creates a temp file in the same directory as the target and atomically replaces
it. If it encounters a symlink and the real file is somehow protected or the filesystem
is in a bad state, it can produce a 0-byte file. After stripping, run a size check:

```bash
find ./rootfs/usr/lib -type f -name '*.so*' | while read -r f; do
    [ $(stat -c%s "$f") -lt 4096 ] && echo "SMALL: $f"
done
```

Restore any zeroed files from the original tarball with `tar -xf ... -C ./rootfs/ ./path/to/file`.

### 6. `/etc/fstab` must be genericized

An LFS fstab contains your build machine's specific `/dev/sdX` partition layout. This
will either fail silently or mount the wrong partitions on a different machine. Always
replace it with a commented template before distributing.

### 7. SSH host keys must never ship

Host keys are machine-unique identifiers. Shipping them means every deployment shares
the same key — a serious security issue. Remove with `rm /etc/ssh/ssh_host_*` and
document that deployers must run `ssh-keygen -A` on first boot.

---

## Size Reference

Typical savings from a bloated LFS build:

| Action | Uncompressed savings |
|---|---|
| Remove cross-compiler libexec | ~1.1G |
| Remove cross-compiler lib + sysroot | ~60M |
| Strip GCC cc1/cc1plus/lto1 debug symbols | ~700M |
| Strip all other ELF binaries | ~100M |
| Remove Python test suite + pycache | ~170M |
| Rebuild locale (en_US only) | ~220M |
| Remove /usr/share/doc + info | ~320M |
| Remove /usr/share/locale (i18n strings) | ~100M |
| Remove sanitizer static libs | ~70M |
| Remove Perl pod documentation | ~15M |

Total: roughly **~2.8G uncompressed** → compresses to ~250MB with zstd.