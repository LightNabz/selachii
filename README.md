# Selachii

> A bored Linux user installed LFS, and he doesn't want to suffer to replicate,  
> but he ended up creating a whole new distro that mimic Gentoo.

Selachii is a minimal, from-scratch Linux distribution based on
[Linux From Scratch (LFS) 13](https://www.linuxfromscratch.org/), using OpenRC as
its init system. It ships as a stage3-like rootfs tarball — just like Gentoo — so
you can extract, chroot, and build on top of it without going through the pain of
building LFS yourself.

---

## Why Selachii?

Selachii is the subclass that sharks belong to. Sharks are built different. So is
this distro (allegedly). Also, sharks are cute and I think the name is really cute.

---

## What's Inside

- **Base:** Linux From Scratch 13
- **Init system:** OpenRC
- **Toolchain:** GCC 15.2.0, glibc 2.43, binutils
- **Languages:** Python 3.14, Perl 5.42
- **Extras:** OpenSSH, Git, dhcpcd, wget
- **Format:** zstd-compressed rootfs tarball (~248MB without Git, ~310MB with Git)
- **Kernel:** Not included — you bring your own or compile one (6.18+ recommended)
- **Package manager:** Not included — this is a bootstrap base, build what you need

---

## Getting Started

### Install Selachii on a machine

See **[INSTALL.md](docs/INSTALL.md)** for the full installation guide covering:

- Partitioning (BIOS/MBR, UEFI, with or without separate `/boot`)
- Extracting the tarball
- Kernel compilation
- GRUB2 setup
- First boot configuration

### Reproduce or customize the tarball

See **[REPRODUCE.md](docs/REPRODUCE.md)** for the full guide on how this tarball was built
and trimmed from a base LFS installation, covering:

- Auditing a completed LFS rootfs
- Safely removing the cross-compiler and dead weight
- Stripping debug symbols without breaking the compiler
- Rebuilding a minimal locale archive
- Pre-pack cleanup (SSH keys, fstab, machine-id, logs)
- Packing the final tarball with zstd

---

## Download

Latest release: [**GitHub Releases →**](https://github.com/LightNabz/selachii/releases)

```
selachii-amd64-YYYYMMDD-X.Y.tar.zst
```

Filename format: `selachii-amd64-$(date +%Y%m%d)-majorchange.hotfix.tar.zst`

---

## Quick Start (for the impatient)

```bash
# Boot a Gentoo Minimal Live ISO, then:
mount /dev/sdX2 /mnt/gentoo

tar --zstd --numeric-owner --xattrs-include='*.*' --acls \
    -xpf selachii-amd64-YYYYMMDD-X.Y.tar.zst \
    -C /mnt/gentoo/

# Mount virtual filesystems
mount --bind /dev /mnt/gentoo/dev
mount --bind /dev/pts /mnt/gentoo/dev/pts
mount -t proc proc /mnt/gentoo/proc
mount -t sysfs sysfs /mnt/gentoo/sys
mount -t tmpfs tmpfs /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash --login
```

Then compile a kernel (6.18+), install GRUB2, set a root password, and reboot.
See [INSTALL.md](INSTALL.md) for the details.

---

## Design Philosophy

- **No package manager** — Selachii is a bootstrap base, not a full distro. Install
  one yourself or build what you need from source.
- **No prebuilt kernel** — hardware varies too much. You know your machine better
  than I do.
- **No bloat** — the tarball is stripped down to what you actually need to bootstrap
  a working system: a compiler, a shell, an init system, and not much else.
- **Stage3-style** — inspired by Gentoo's approach of shipping a minimal rootfs that
  users build on top of rather than a full installation image.

---

## Requirements

| Component | Minimum |
|---|---|
| Architecture | x86_64 |
| RAM | 512MB (2GB+ for kernel compilation) |
| Disk | 8GB (16GB+ recommended) |
| Kernel | 6.18 or newer (user-supplied) |
| Boot mode | BIOS or UEFI |

---

## First Boot Checklist

After installing, do these before anything else:

```bash
passwd root          # set a root password — tarball ships with locked account
ssh-keygen -A        # generate fresh SSH host keys
# edit /etc/fstab    # set your actual partition UUIDs
# edit /etc/hostname # set your hostname
```

---

## License

The scripts and documentation in this repository are released under the MIT License.

The software contained in the tarball is subject to the licenses of each respective
upstream project (GCC, glibc, OpenRC, etc.).

---

*Built with suffering, curiosity, and an unreasonable fondness for sharks.*