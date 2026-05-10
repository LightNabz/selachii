# Selachii Installation Guide

Selachii is a minimal LFS-based Linux distribution distributed as a stage3-style
tarball. This guide walks you through installing it on a real machine or virtual
machine from scratch.

**Assumed knowledge:** Basic Linux command line usage, familiarity with partitioning
concepts, and comfort working in a terminal. You do not need to have built LFS before.

---

## Table of Contents

1. [What You Need](#what-you-need)
2. [Boot the Live Environment](#boot-the-live-environment)
3. [Partition the Disk](#partition-the-disk)
4. [Format the Partitions](#format-the-partitions)
5. [Mount the Partitions](#mount-the-partitions)
6. [Extract the Stage3 Tarball](#extract-the-stage3-tarball)
7. [Configure the System](#configure-the-system)
8. [Enter the Chroot](#enter-the-chroot)
9. [Kernel](#kernel)
10. [Install GRUB2](#install-grub2)
11. [Final Configuration](#final-configuration)
12. [Reboot](#reboot)
13. [Post-Install](#post-install)
14. [Troubleshooting](#troubleshooting)

---

## What You Need

- A 64-bit x86 machine (physical or virtual)
- At least **8GB** of disk space (16GB+ recommended if you plan to compile software)
- At least **512MB** RAM (2GB+ recommended for kernel compilation)
- Internet access from the live environment
- A Selachii stage3 tarball — download the latest release from
  **https://github.com/LightNabz/selachii/releases**

```
selachii-amd64-YYYYMMDD-X.Y.tar.zst
```

- A Linux live image to boot from — **Gentoo Minimal Live ISO is recommended**
  Download: https://www.gentoo.org/downloads/ (pick the **Minimal Installation CD**, amd64)

> **Why Gentoo Minimal?** It ships with all the tools you need (fdisk, mkfs.ext4,
> tar with zstd support, chroot) without bloat. Any other Linux live ISO that has
> `tar` with zstd support works too.

---

## Boot the Live Environment

1. Write the Gentoo Minimal ISO to a USB drive:

```bash
# Replace /dev/sdX with your USB device — double check with lsblk first
dd if=install-amd64-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

2. Boot from the USB. On most machines press `F12`, `F2`, or `Del` during POST to
   access the boot menu.

3. At the Gentoo boot prompt, press Enter to boot the default option.

4. Once booted, you will be at a root shell. Verify internet connectivity:

```bash
ping -c 3 gentoo.org
```

If you are on Wi-Fi, see the [Gentoo Handbook networking section](https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Networking)
for `wpa_supplicant` setup. Wired connections usually come up automatically.

---

## Partition the Disk

Identify your target disk:

```bash
lsblk
# or
fdisk -l
```

Common disk names: `/dev/sda` (SATA/USB), `/dev/nvme0n1` (NVMe), `/dev/vda` (VirtIO).

> **Warning:** The following steps erase all data on the target disk. Double-check
> you have the right device before proceeding.

Choose the layout that matches your system:

---

### Layout A — BIOS/MBR (Legacy Boot)

Use this if your machine boots in legacy BIOS mode (not UEFI), or if you are
installing to a VM without UEFI.

```
/dev/sdX1   swap     2G     (optional but recommended)
/dev/sdX2   /        rest   ext4
```

```bash
fdisk /dev/sdX
```

Inside fdisk:
```
o        # create new MBR partition table
n        # new partition (swap)
p        # primary
1        # partition number 1
[Enter]  # default first sector
+2G      # 2GB for swap
t        # change type
82       # Linux swap

n        # new partition (root)
p
2
[Enter]  # default first sector
[Enter]  # use remaining space

w        # write and exit
```

---

### Layout B — UEFI/GPT with EFI System Partition

Use this if your machine boots in UEFI mode. Check with:

```bash
ls /sys/firmware/efi && echo "UEFI" || echo "BIOS"
```

```
/dev/sdX1   /boot/efi    512M   EFI System Partition (FAT32)
/dev/sdX2   swap         2G     Linux swap
/dev/sdX3   /            rest   ext4
```

```bash
fdisk /dev/sdX
```

Inside fdisk:
```
g        # create new GPT partition table

n        # EFI partition
1
[Enter]
+512M
t
1        # EFI System

n        # swap
2
[Enter]
+2G
t
2
19       # Linux swap

n        # root
3
[Enter]
[Enter]  # use remaining space

w
```

---

### Layout C — UEFI/GPT with Separate /boot

Use this if you want `/boot` on its own partition (useful for encrypted root setups
later, or when GRUB needs to read kernels from a dedicated partition).

```
/dev/sdX1   /boot/efi    512M   EFI System Partition (FAT32)
/dev/sdX2   /boot        1G     ext4
/dev/sdX3   swap         2G     Linux swap
/dev/sdX4   /            rest   ext4
```

Follow the same fdisk steps as Layout B but add a fourth partition for root, and
assign partition 2 as a regular Linux partition (type 20) for `/boot`.

---

## Format the Partitions

Substitute the correct device names for your layout.

### Layout A (BIOS/MBR)

```bash
mkswap /dev/sdX1
mkfs.ext4 /dev/sdX2
```

### Layout B (UEFI, no separate /boot)

```bash
mkfs.fat -F32 /dev/sdX1
mkswap /dev/sdX2
mkfs.ext4 /dev/sdX3
```

### Layout C (UEFI, separate /boot)

```bash
mkfs.fat -F32 /dev/sdX1
mkfs.ext4 /dev/sdX2
mkswap /dev/sdX3
mkfs.ext4 /dev/sdX4
```

---

## Mount the Partitions

### Layout A (BIOS/MBR)

```bash
swapon /dev/sdX1
mount /dev/sdX2 /mnt/gentoo
```

### Layout B (UEFI, no separate /boot)

```bash
swapon /dev/sdX2
mount /dev/sdX3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount /dev/sdX1 /mnt/gentoo/boot/efi
```

### Layout C (UEFI, separate /boot)

```bash
swapon /dev/sdX3
mount /dev/sdX4 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mkdir -p /mnt/gentoo/boot
mount /dev/sdX2 /mnt/gentoo/boot
mount /dev/sdX1 /mnt/gentoo/boot/efi
```

> The Gentoo live ISO uses `/mnt/gentoo` as the conventional install target. You can
> use any empty directory — just substitute it consistently throughout this guide.

---

## Extract the Stage3 Tarball

Copy or download the Selachii tarball to the live environment, then extract:

```bash
# If downloading directly — get the exact filename from:
# https://github.com/LightNabz/selachii/releases
wget https://github.com/LightNabz/selachii/releases/download/TAGNAME/selachii-amd64-YYYYMMDD-X.Y.tar.zst

# Extract — this preserves permissions, xattrs, and ACLs
tar --zstd \
    --numeric-owner \
    --xattrs-include='*.*' \
    --acls \
    -xpf selachii-amd64-YYYYMMDD-X.Y.tar.zst \
    -C /mnt/gentoo/

# Verify extraction
ls /mnt/gentoo/usr /mnt/gentoo/etc /mnt/gentoo/bin
```

The flags matter here:
- `--numeric-owner` — restores uid/gid by number, not name
- `--xattrs-include='*.*'` — restores extended attributes
- `--acls` — restores access control lists
- `-p` — restores permissions exactly

---

## Configure the System

### /etc/fstab

Get the UUIDs of your partitions — UUIDs are preferred over `/dev/sdX` names because
device names can change between boots:

```bash
blkid
```

Edit the fstab inside the new installation:

```bash
nano /mnt/gentoo/etc/fstab
```

#### Layout A (BIOS/MBR)

```
# <filesystem>                          <mountpoint>  <type>  <options>         <dump> <pass>
UUID=YOUR-ROOT-UUID                     /             ext4    defaults          1      1
UUID=YOUR-SWAP-UUID                     none          swap    sw                0      0
```

#### Layout B (UEFI, no separate /boot)

```
UUID=YOUR-ROOT-UUID                     /             ext4    defaults          1      1
UUID=YOUR-EFI-UUID                      /boot/efi     vfat    defaults          0      2
UUID=YOUR-SWAP-UUID                     none          swap    sw                0      0
```

#### Layout C (UEFI, separate /boot)

```
UUID=YOUR-ROOT-UUID                     /             ext4    defaults          1      1
UUID=YOUR-BOOT-UUID                     /boot         ext4    defaults          0      2
UUID=YOUR-EFI-UUID                      /boot/efi     vfat    defaults          0      2
UUID=YOUR-SWAP-UUID                     none          swap    sw                0      0
```

Replace each `YOUR-*-UUID` with the actual UUID from `blkid` output.

### Hostname

```bash
echo "yourhostname" > /mnt/gentoo/etc/hostname
```

### DNS (for inside the chroot)

```bash
cp /etc/resolv.conf /mnt/gentoo/etc/resolv.conf
```

---

## Enter the Chroot

Mount the virtual kernel filesystems, then chroot in:

```bash
mount --bind /dev  /mnt/gentoo/dev
mount --bind /dev/pts /mnt/gentoo/dev/pts
mount -t proc  proc  /mnt/gentoo/proc
mount -t sysfs sysfs /mnt/gentoo/sys
mount -t tmpfs tmpfs /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash --login
```

Verify the environment:

```bash
gcc --version
python3 --version
echo $PATH
# Expected: /usr/bin:/usr/sbin or similar
```

---

## Kernel

Selachii does not ship a prebuilt kernel. You need to either compile one or supply one
from another source.

**Recommended kernel version: 6.18 or newer.** Older kernels may work but are not
tested against this toolchain.

### Option A — Compile your own kernel (recommended)

You will need the kernel source. Either copy it into the chroot or download it:

```bash
# Inside chroot
cd /usr/src

# Download kernel 6.18 or newer from https://kernel.org
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.tar.xz
tar -xf linux-6.18.tar.xz
ln -s linux-6.18 linux
cd linux
```

Configure the kernel. If you are new to kernel configuration, `defconfig` is a safe
starting point:

```bash
make defconfig
```

For interactive configuration (recommended for experienced users):

```bash
make menuconfig
```

Key options to verify are enabled for a bootable system:

- `CONFIG_EXT4_FS` — ext4 filesystem support
- `CONFIG_BLK_DEV_SD` — SATA/SCSI disk support
- `CONFIG_NVME_CORE` + `CONFIG_BLK_DEV_NVME` — NVMe support (if applicable)
- `CONFIG_EFI_STUB` — required for UEFI boot
- `CONFIG_EFI` — EFI runtime support
- Drivers for your network card

Compile:

```bash
# -j$(nproc) uses all available CPU cores
make -j$(nproc)
make modules_install

# Install the kernel image
cp arch/x86/boot/bzImage /boot/vmlinuz-6.18
cp System.map /boot/System.map-6.18
cp .config /boot/config-6.18
```

### Option B — Copy a kernel from another system

If you have a working kernel from another Linux installation:

```bash
# From outside chroot, copy from the live environment's /boot
cp /boot/vmlinuz-* /mnt/gentoo/boot/
cp /boot/System.map-* /mnt/gentoo/boot/
```

Note that kernel modules must match the kernel version. Mismatched modules will cause
boot failures.

### Initramfs

If your root filesystem requires an initramfs (e.g. for module loading at boot),
you need to generate one. Selachii does not include an initramfs generator by default.
Options:

- **dracut** — install and run `dracut --force /boot/initramfs-6.18.img 6.18`
- **mkinitcpio** — Arch-style initramfs generator
- **No initramfs** — works if all required drivers (disk, filesystem) are compiled
  directly into the kernel (not as modules), which `defconfig` typically does

---

## Install GRUB2

> **Note:** Selachii does not ship GRUB2. You need to compile and install it yourself
> before it can be used as a bootloader. Follow the BLFS guide for building GRUB2
> from source:
>
> **https://www.linuxfromscratch.org/blfs/view/12.3/postlfs/grub-setup.html**
>
> That guide covers obtaining the source, dependencies, building, and the exact
> `grub-install` invocation for both BIOS and UEFI systems. Come back here once
> GRUB2 is installed and continue with `grub-mkconfig` below.

>**NOTE:** All neceessary dependencies for Grub2 were already built-in inside the tarball, better to double check it.

### BIOS/MBR systems

```bash
# Install GRUB to the MBR of the disk (not a partition)
grub-install /dev/sdX

# Generate the GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
```

### UEFI systems

```bash
# Verify the EFI partition is mounted
ls /boot/efi

# Install GRUB for UEFI
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=Selachii

# Generate the GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
```

Verify GRUB found your kernel:

```bash
cat /boot/grub/grub.cfg | grep menuentry
```

You should see at least one `menuentry` block referencing your kernel in `/boot`.

If `grub-mkconfig` does not find the kernel automatically, you can add a manual entry
to `/boot/grub/grub.cfg`. Here is an example for a UEFI system:

```
menuentry "Selachii" {
    insmod part_gpt
    insmod ext2
    search --no-floppy --fs-uuid --set=root YOUR-ROOT-UUID
    linux  /boot/vmlinuz-6.18 root=UUID=YOUR-ROOT-UUID rw quiet
    initrd /boot/initramfs-6.18.img
}
```

Remove the `initrd` line if you are not using an initramfs.

---

## Final Configuration

### Root password

```bash
passwd root
```

Choose a strong password. The stage3 ships with a locked root account — this step
is mandatory before rebooting.

### SSH host keys

```bash
ssh-keygen -A
```

This generates fresh host keys unique to your installation. The stage3 does not ship
host keys.

### Timezone

```bash
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
# Example: ln -sf /usr/share/zoneinfo/Asia/Makassar /etc/localtime
```

Browse available timezones:

```bash
ls /usr/share/zoneinfo/
ls /usr/share/zoneinfo/Asia/
```

### Locale

The stage3 ships with `en_US.UTF-8` pre-generated. Set it as the system default:

```bash
cat > /etc/locale.conf << 'EOF'
LANG=en_US.UTF-8
LC_COLLATE=C
EOF
```

If you need additional locales, you will need to supply `/usr/share/i18n` (not included
in the stage3 to save space) and run `localedef`.

### Clock

```bash
# Set hardware clock to UTC (recommended)
hwclock --systohc --utc
```

### OpenRC services

Enable essential services:

```bash
# SSH daemon (if you want remote access)
rc-update add sshd default

# dhcpcd for wired network (see Post-Install for other options)
rc-update add dhcpcd default

# System logger (if installed)
# rc-update add sysklogd default
```

List available services:

```bash
rc-update show
```

---

## Reboot

Exit the chroot, unmount everything, and reboot:

```bash
# Exit chroot
exit

# Unmount in reverse order
umount /mnt/gentoo/dev/pts
umount /mnt/gentoo/dev
umount /mnt/gentoo/proc
umount /mnt/gentoo/sys
umount /mnt/gentoo/run

# UEFI layouts — unmount boot partitions
# umount /mnt/gentoo/boot/efi
# umount /mnt/gentoo/boot   # if separate /boot

umount /mnt/gentoo
swapoff /dev/sdX1   # or whichever partition is swap

reboot
```

Remove the live USB when the machine starts shutting down.

---

## Post-Install

### Networking

Selachii ships **dhcpcd** for wired DHCP networking. It is enabled automatically if
you ran `rc-update add dhcpcd default` above.

For more advanced networking (Wi-Fi, static IPs, NetworkManager, etc.) refer to:

- **NetworkManager:** https://wiki.gentoo.org/wiki/NetworkManager
- **wpa_supplicant (Wi-Fi):** https://wiki.gentoo.org/wiki/Wpa_supplicant
- **Static IP with dhcpcd:** https://wiki.gentoo.org/wiki/Dhcpcd

### Adding a regular user

Running as root permanently is not recommended:

```bash
useradd -m -G wheel,audio,video,usb,cdrom -s /bin/bash yourname
passwd yourname
```

### Building software

Selachii ships a full GCC toolchain. To compile software from source:

```bash
# Standard autotools build
./configure --prefix=/usr
make -j$(nproc)
make install
```

You may want to install a package manager such as **Portage** (Gentoo) or build
packages manually. Selachii does not ship a package manager by default.

### Kernel modules

If you compiled kernel modules, load them with:

```bash
modprobe module_name
```

To load a module automatically at boot, add it to `/etc/modules-load.d/`:

```bash
echo "module_name" > /etc/modules-load.d/module_name.conf
```

---

## Troubleshooting

### System does not boot — GRUB prompt appears

GRUB loaded but cannot find the kernel or config. At the GRUB prompt:

```bash
ls                          # list detected disks and partitions
ls (hd0,gpt2)/boot/         # check if kernel is there
```

Boot manually:

```bash
linux (hd0,gpt2)/boot/vmlinuz-6.x.y root=/dev/sdX2 rw
boot
```

Then fix `grub.cfg` after booting.

### Kernel panic — not syncing: VFS: Unable to mount root fs

The kernel cannot find or mount the root partition. Common causes:

- Wrong `root=` in GRUB config — verify the UUID matches `blkid` output
- Root filesystem driver not compiled into kernel — recompile with `CONFIG_EXT4_FS=y`
- NVMe/SATA driver missing — recompile with the correct storage driver built-in

### gcc: error while loading shared libraries

A shared library was corrupted or is missing. Boot the live environment, mount the
root partition, and restore the affected library from the original stage3 tarball:

```bash
mount /dev/sdX2 /mnt/gentoo
tar -xf selachii-amd64-YYYYMMDD-X.Y.tar.zst \
    -C /mnt/gentoo/ \
    ./usr/lib/libaffected.so.X.Y
```

### No network after boot

Check if dhcpcd is running:

```bash
rc-service dhcpcd status
rc-service dhcpcd start
```

Check your interface name:

```bash
ip link
```

If your interface is not `eth0` (e.g. it is `enp3s0`), dhcpcd may need to be pointed
at it explicitly:

```bash
dhcpcd enp3s0
```

### SSH host key errors when connecting

The stage3 ships without host keys. If you forgot to run `ssh-keygen -A` before
rebooting, run it now from the local console:

```bash
ssh-keygen -A
rc-service sshd restart
```

### Clock is wrong

```bash
# Sync from NTP (requires network)
ntpd -q -g   # if ntpd is installed

# Or set manually
date MMDDHHmmYYYY
hwclock --systohc
```

---

*For issues not covered here, refer to the [LFS Book](https://www.linuxfromscratch.org/lfs/view/stable/)
and the [Gentoo Handbook](https://wiki.gentoo.org/wiki/Handbook:AMD64) — both are
excellent references for the kind of system Selachii is built on.*