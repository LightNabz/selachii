# Selachii Linux

> A bored Linux user installed LFS, and he doesn't want to suffer to replicate, but he ended up creating a whole new distro mimicking Gentoo.

Selachii is a minimal, from-scratch Linux distribution based on [Linux From Scratch (LFS) 13](https://www.linuxfromscratch.org/), using OpenRC as its init system. It ships as a stage3-like rootfs tarball — just like Gentoo — so you can extract, chroot, and build on top of it without going through the pain of building LFS yourself.

---

## 📦 What's Included

- **Base system** — GNU Coreutils, Bash 5.3, glibc 2.43
- **Init system** — OpenRC
- **Compiler toolchain** — GCC 15.2.0, Binutils, Make
- **Network** — dhcpcd, wget, curl
- **Remote access** — OpenSSH (sshd)
- **Utilities** — vim, gawk, zstd, sqlite3, udev
- **Eye candy** — fastfetch

---

## 🚀 Getting Started

### Extract the rootfs

```bash
mkdir ./selachii
sudo tar -xJpf selachii-26.0.0-amd64.tar.xz \
  --xattrs-include='*.*' \
  --numeric-owner \
  -C ./selachii
```

### Mount virtual filesystems

```bash
sudo mount -v --bind /dev ./selachii/dev
sudo mount -v --bind /dev/pts ./selachii/dev/pts
sudo mount -vt proc proc ./selachii/proc
sudo mount -vt sysfs sysfs ./selachii/sys
sudo mount -vt tmpfs tmpfs ./selachii/run
```

### Chroot in

```bash
sudo chroot ./selachii /usr/bin/env -i \
  HOME=/root \
  TERM=xterm \
  PS1='(selachii) \u:\w\$ ' \
  PATH=/usr/bin:/usr/sbin \
  /bin/bash --login
```

### Unmount when done

```bash
sudo umount -R /path/to/selachii
```

> For further installation guide, you might refer to [Installation Guide](docs/INSTALL.md)
---

## 💿 Installing to Disk

1. Partition your disk (at minimum a root partition)
2. Format and mount it:
```bash
mkfs.ext4 /dev/sdXY
mount /dev/sdXY /mnt/selachii
```
3. Extract the tarball to it:
```bash
sudo tar -xJpf selachii-26.0.0-amd64.tar.xz \
  --xattrs-include='*.*' \
  --numeric-owner \
  -C /mnt/selachii
```
4. Chroot in and set up bootloader (GRUB), fstab, and kernel manually
5. Reboot and suffer less than LFS 🙏

---

## 📋 System Info

| Property | Value |
|----------|-------|
| Base | Linux From Scratch 13 |
| Init | OpenRC |
| Architecture | x86_64 (amd64) |
| libc | glibc 2.43 |
| GCC | 15.2.0 |
| Kernel (tested) | Linux 6.18.10 |
| Version scheme | YY.MajorUpdate.Hotfix |

---

## ⚠️ Notes

- No kernel included — bring your own
- No bootloader configured — set up GRUB yourself
- Root has no password by default — set one immediately after chrooting
- This is a stage3-equivalent, not a ready-to-boot system out of the box

---

## 🦈 Why "Selachii"?

Selachii is the subclass that sharks belong to. Sharks are built different. So is this distro (allegedly). Also, sharks are cute and I think the name is really cute.

---

## 📜 License

Do whatever you want with it. It's just LFS with extra steps and a cool name.

> WARNING: FILES IN THE SOURCE CODE WERE PARTIALLY VIBE CODED (I don't have enough time to tidy things up)
