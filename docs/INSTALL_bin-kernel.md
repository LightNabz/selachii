# 🦈 Selachii Linux — Installing a Kernel (Stolen from Somewhere Else)

So you don't want to compile a kernel. Understandable. Compiling takes forever and life is short. This guide shows you how to yoink a precompiled kernel from Gentoo, Arch, Debian, or literally anywhere else and make it work on Selachii.

No shame here. Even Gentoo users do this sometimes. 🙏

---

## ⚠️ Before You Start

Stolen kernels come with caveats:
- **Modules must match the kernel version exactly** — mismatch = broken modules
- **Config is someone else's** — might include stuff you don't need, might miss stuff you do
- **It'll probably work fine tho** 😭

---

## 🥷 Option 1 — Steal from Gentoo LiveCD (Easiest)

You're already booted into a live environment. The kernel is right there.

```bash
# check what kernel the live env is running
uname -r

# copy the kernel image
cp /boot/vmlinuz /mnt/selachii/boot/vmlinuz-$(uname -r)

# copy the modules
cp -r /lib/modules/$(uname -r) /mnt/selachii/lib/modules/

# copy system map if available
cp /boot/System.map /mnt/selachii/boot/System.map-$(uname -r) 2>/dev/null || echo "no System.map, that's fine"
```

---

## 🥷 Option 2 — Steal from Arch Linux

On an Arch machine or Arch live environment:

```bash
# find the kernel
ls /boot/vmlinuz*

# copy kernel and initramfs
cp /boot/vmlinuz-linux /mnt/selachii/boot/
cp /boot/initramfs-linux.img /mnt/selachii/boot/ 2>/dev/null || true

# copy modules
cp -r /lib/modules/$(uname -r) /mnt/selachii/lib/modules/
```

> Note: Arch kernels are named `vmlinuz-linux`, just rename it if GRUB gets confused

---

## 🥷 Option 3 — Steal from Debian/Ubuntu Package

No live environment? Download the .deb and extract it like a scoundrel:

```bash
# on any Debian/Ubuntu system or live env
apt-get download linux-image-amd64

# extract the .deb
dpkg-deb -x linux-image-*.deb ./kernel-extract

# copy what you need
cp ./kernel-extract/boot/vmlinuz-* /mnt/selachii/boot/
cp -r ./kernel-extract/lib/modules/* /mnt/selachii/lib/modules/
```

---

## 🥷 Option 4 — Download a Precompiled Kernel from kernel.org

```bash
# some distros publish precompiled kernels
# Arch for example has them in their repos
# grab the package, extract, copy

# or just use the Arch one directly
wget https://mirror.rackspace.com/archlinux/core/os/x86_64/linux-6.12.1.arch1-1-x86_64.pkg.tar.zst
tar xf linux-*.pkg.tar.zst
cp boot/vmlinuz-linux /mnt/selachii/boot/
cp -r lib/modules/* /mnt/selachii/lib/modules/
```

---

## 🥾 Install GRUB (Same Regardless of Where You Stole From)

Chroot into Selachii first:

```bash
sudo mount -v --bind /dev /mnt/selachii/dev
sudo mount -v --bind /dev/pts /mnt/selachii/dev/pts
sudo mount -vt proc proc /mnt/selachii/proc
sudo mount -vt sysfs sysfs /mnt/selachii/sys
sudo mount -vt tmpfs tmpfs /mnt/selachii/run
sudo mount /dev/sdX1 /mnt/selachii/boot/efi

sudo chroot /mnt/selachii /usr/bin/env -i \
  HOME=/root TERM=xterm \
  PATH=/usr/bin:/usr/sbin \
  /bin/bash --login
```

Then install GRUB:

```bash
grub-install --target=x86_64-efi \
             --efi-directory=/boot/efi \
             --bootloader-id=Selachii

grub-mkconfig -o /boot/grub/grub.cfg
```

---

## 🚪 Reboot

```bash
exit
sudo umount -R /mnt/selachii
sudo reboot
```

---

## 🩹 Troubleshooting

**Kernel boots but modules are broken**
The kernel version and modules directory must match exactly. Check with:
```bash
uname -r
ls /lib/modules/
```
If they don't match, go steal the right version. 😭

**Kernel panic: not syncing**
The kernel can't find root. Make sure your `/etc/fstab` is correct and GRUB has the right root= parameter.

```bash
# check grub config
cat /boot/grub/grub.cfg | grep root=
```

**System boots to black screen**
Probably a display driver issue with the stolen kernel config. Not much you can do except compile your own (see `INSTALL_compile-kernel.md`) or steal from a different distro. 🙏

---

> 🦈 You stole a kernel and it works. Sharks don't write kernel configs from scratch either. Efficiency is a virtue.
