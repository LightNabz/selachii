# 🦈 Selachii Linux — Installation Guide

This guide walks you through installing Selachii Linux to a real or virtual disk from scratch. You'll need a live Linux environment (Arch, Gentoo, whatever) to do this.

---

## 📋 Prerequisites

- A live Linux environment (USB, LiveCD, whatever)
- The `selachii-26.0.0-amd64.tar.xz` tarball
- A target disk to install to
- Basic knowledge that you're about to do something slightly unhinged

---

## 🗂️ Step 1 — Partition Your Disk

Use `fdisk`, `cfdisk`, or `parted`. Recommended layout:

| Partition | Size | Type | Filesystem |
|-----------|------|------|------------|
| /dev/sdX1 | 512MB | EFI System | FAT32 |
| /dev/sdX2 | 4GB+ | Linux Swap | swap |
| /dev/sdX3 | Rest | Linux filesystem | ext4 |

```bash
cfdisk /dev/sdX
```

Format them:

```bash
# EFI
mkfs.fat -F32 /dev/sdX1

# Swap
mkswap /dev/sdX2
swapon /dev/sdX2

# Root
mkfs.ext4 /dev/sdX3
```

---

## 📦 Step 2 — Extract the Tarball

```bash
mount /dev/sdX3 /mnt/selachii
mkdir -p /mnt/selachii/boot/efi

sudo tar -xJpf selachii-26.0.0-amd64.tar.xz \
  --xattrs-include='*.*' \
  --numeric-owner \
  -C /mnt/selachii
```

---

## 🔧 Step 3 — Mount Virtual Filesystems

```bash
sudo mount -v --bind /dev /mnt/selachii/dev
sudo mount -v --bind /dev/pts /mnt/selachii/dev/pts
sudo mount -vt proc proc /mnt/selachii/proc
sudo mount -vt sysfs sysfs /mnt/selachii/sys
sudo mount -vt tmpfs tmpfs /mnt/selachii/run
```

Mount EFI:

```bash
mount /dev/sdX1 /mnt/selachii/boot/efi
```

---

## 🐚 Step 4 — Chroot In

```bash
sudo chroot /mnt/selachii /usr/bin/env -i \
  HOME=/root \
  TERM=xterm \
  PS1='(selachii-chroot) \u:\w\$ ' \
  PATH=/usr/bin:/usr/sbin \
  /bin/bash --login
```

---

## ⚙️ Step 5 — Basic Configuration

### Set root password (do this immediately)

```bash
passwd root
```

### Set hostname

```bash
echo "yourhostname" > /etc/hostname
```

### Configure /etc/fstab

```bash
cat > /etc/fstab << EOF
# <device>    <mountpoint>  <type>  <options>          <dump> <pass>
/dev/sdX3     /             ext4    defaults           1      1
/dev/sdX1     /boot/efi     vfat    umask=0077         0      1
/dev/sdX2     none          swap    sw                 0      0
EOF
```

> Use UUIDs for production — get them with `blkid`

### Set timezone

```bash
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
```

### Configure network interface

```bash
# make sure dhcpcd starts on boot with your interface
rc-update add dhcpcd default
```

Edit `/etc/conf.d/dhcpcd` if needed to specify your interface.

---

## 🐧 Step 6 — Install a Kernel

Selachii ships no kernel, bring your own:

```bash
# grab kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.10.tar.xz
tar xf linux-6.18.10.tar.xz
cd linux-6.18.10

# configure and build
make defconfig
make -j$(nproc)
make modules_install

# copy kernel and System.map
cp arch/x86/boot/bzImage /boot/vmlinuz-6.18.10
cp System.map /boot/System.map-6.18.10
```

> For further detail, you might refer to [Compile From Source](INSTALL_compile-kernel.md) or [Binary Kernel](INSTALL_bin-kernel.md)

---

## 🥾 Step 7 — Install GRUB

```bash
# install grub to EFI
grub-install --target=x86_64-efi \
             --efi-directory=/boot/efi \
             --bootloader-id=Selachii

# generate config
grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 🚪 Step 8 — Exit and Reboot

```bash
exit
```

Unmount everything:

```bash
sudo umount -R /mnt/selachii
sudo reboot
```

Select Selachii from your bootloader and you're in 🦈

---

## 🩹 Troubleshooting

**No internet after boot**
```bash
rc-service dhcpcd start
rc-update add dhcpcd default
```

**SSH not starting**
```bash
ssh-keygen -A
rc-service sshd start
rc-update add sshd default
```

**Wrong OS name in fastfetch**
```bash
# edit /etc/fastfetch/config.jsonc and adjust the OS format field
```

**Forgot to set root password and now locked out**
Boot from live environment, chroot back in, run `passwd root` 😭

---

## 📜 Post-Install Recommendations

- Set up a non-root user: `useradd -m -G wheel username`
- Set user password: `passwd username`
- Configure SSH keys for remote access
- Build and install any additional software from source (it's LFS, that's the whole point)

---

> 🦈 You're now running Selachii Linux. You did this to yourself and we're proud of you.
