# 🦈 Selachii Linux — Installing a Kernel (Compiled from Source)

So you decided to do it the right way. Respect. This will take a while. Go make a coffee. ☕

---

## 📋 Prerequisites

- You are chrooted into Selachii **or** on a running Selachii system
- GCC, Make, Binutils are already there (they are, relax)
- At least 15GB of free space for kernel source + build artifacts
- Time. A lot of it.

---

## 📦 Step 1 — Grab the Kernel Source

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.10.tar.xz
tar xf linux-6.18.10.tar.xz
cd linux-6.18.10
```

Check https://kernel.org for the latest stable version if you want something newer.

---

## ⚙️ Step 2 — Configure the Kernel

### Option A — defconfig (easy, works most of the time)

```bash
make defconfig
```

Good enough for most hardware and VMs. Use this if you have no idea what you're doing and that's okay.

### Option B — menuconfig (full control, full responsibility)

```bash
make menuconfig
```

A TUI will open. You configure every single kernel option manually. This is where you either craft a perfectly optimized kernel or spend 3 hours and end up with a system that won't boot. Good luck. 🙏

### Option C — localmodconfig (copy running kernel config)

If you're running from a live environment:

```bash
make localmodconfig
```

Copies only the modules currently loaded on the live system. Smaller kernel, might miss stuff.

---

## 🔨 Step 3 — Build It

```bash
make -j$(nproc)
```

`$(nproc)` uses all your CPU cores. This will take anywhere from 5 minutes on a beefy machine to 45 minutes on a potato. Totally normal. Don't panic.

---

## 📥 Step 4 — Install Modules and Kernel

```bash
# install kernel modules
make modules_install

# copy kernel image
cp arch/x86/boot/bzImage /boot/vmlinuz-6.18.10

# copy system map (for debugging)
cp System.map /boot/System.map-6.18.10

# copy config (for future reference)
cp .config /boot/config-6.18.10
```

---

## 🥾 Step 5 — Install GRUB

```bash
# install grub to EFI partition
grub-install --target=x86_64-efi \
             --efi-directory=/boot/efi \
             --bootloader-id=Selachii

# generate grub config
grub-mkconfig -o /boot/grub/grub.cfg
```

Make sure `/boot/efi` is mounted before running this.

---

## 🚪 Step 6 — Reboot

```bash
exit  # if in chroot
sudo umount -R /mnt/selachii
sudo reboot
```

Select Selachii from GRUB and pray. 🙏

---

## 🩹 Troubleshooting

**Kernel panic on boot**
Boot back into live environment, chroot in, and either recompile with different config options or just steal a kernel like a normal person (see `INSTALL_stole-compiled-kernel.md`).

**GRUB not showing Selachii**
```bash
grub-mkconfig -o /boot/grub/grub.cfg
```
Run this again, make sure `/boot/vmlinuz-6.18.10` actually exists.

**Missing modules after boot**
You probably used `localmodconfig` and missed some drivers. Recompile with `defconfig` or `menuconfig` and enable what you need.

---

> 🦈 You compiled a kernel from scratch. You are built different. Sharks don't kernel panic.
