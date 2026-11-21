#!/bin/bash
#set -Eeuo pipefail


echo "Configuring DecksmithOS base runtime"
install -v -m 644 files/config.txt "${ROOTFS_DIR}/boot/firmware/config.txt"
install -v -m 644 files/waveshare28-v2.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare28-v2.dtbo"
install -v -m 644 files/waveshare32b.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare32b.dtbo"
install -v -m 644 files/waveshare32c.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare32c.dtbo"
install -v -m 644 files/waveshare35a.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare35a.dtbo"
install -v -m 644 files/waveshare35b.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare35b.dtbo"
install -v -m 644 files/waveshare35b-v2.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare35b-v2.dtbo"
install -v -m 644 files/waveshare35c.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare35c.dtbo"
install -v -m 644 files/waveshare4c.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/waveshare4c.dtbo"

install -v -m 644 files/apt-conf.local "${ROOTFS_DIR}/etc/apt/apt.conf.d/99local"

# Plymouth: common theme files. plymouthd.conf and decksmithos.script are
# display-specific and installed by ../03-display-profile.
mkdir -p "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos"
install -v -m 644 files/decksmithos.plymouth "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos/decksmithos.plymouth"
install -v -m 644 files/splash.png "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos/splash.png"

install -v -m 644 files/decksmithos-storage-init.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-storage-init.service"
install -v -m 755 files/decksmithos-init-storage "${ROOTFS_DIR}/usr/local/sbin/decksmithos-init-storage"
install -v -m 755 files/decksmithos-mixxx "${ROOTFS_DIR}/usr/local/bin/decksmithos-mixxx"
install -v -m 755 files/decksmithos-mixxx-autoconf files/decksmithos-mixxx-ui files/decksmithos-soundconfig "${ROOTFS_DIR}/usr/local/bin/"
# A/B slot selection via the bootloader's tryboot mode (autoboot.txt on p1).
install -v -m 755 files/decksmithos-slot "${ROOTFS_DIR}/usr/local/sbin/decksmithos-slot"
# Read-only root: decksmithos-overlay-init runs as init= (cmdline.txt written by
# build/postprocess.sh) and needs these two mount points in the image.
install -v -m 755 files/decksmithos-overlay-init "${ROOTFS_DIR}/usr/local/sbin/decksmithos-overlay-init"
install -v -d -m 755 "${ROOTFS_DIR}/media/root-ro" "${ROOTFS_DIR}/media/root-rw"
install -v -m 755 files/decksmithos-rootfs "${ROOTFS_DIR}/usr/local/sbin/decksmithos-rootfs"

# Read-only USB storage in two slots (/usb, /usb2), mounted in order of insertion.
install -v -m 755 files/decksmithos-usb-mount "${ROOTFS_DIR}/usr/local/sbin/decksmithos-usb-mount"
install -v -m 644 files/decksmithos-usb-mount@.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-usb-mount@.service"
install -v -m 644 files/99-decksmithos-usb-storage.rules "${ROOTFS_DIR}/etc/udev/rules.d/99-decksmithos-usb-storage.rules"
install -d -m 755 "${ROOTFS_DIR}/usb" "${ROOTFS_DIR}/usb2"
# Mixxx's Rekordbox feature only looks for devices under /media/*.
install -d -m 755 "${ROOTFS_DIR}/media"
ln -sfn /usb "${ROOTFS_DIR}/media/usb"
ln -sfn /usb2 "${ROOTFS_DIR}/media/usb2"

# Stable ALSA name "decksmithos" for the controller's USB audio (see decksmithos-mixxx).
install -v -m 644 files/asound.conf "${ROOTFS_DIR}/etc/asound.conf"

on_chroot <<EOF
systemctl enable decksmithos-storage-init.service

systemctl disable serial-getty@ttyAMA0.service || true
systemctl disable bluetooth || true
systemctl disable avahi-daemon || true
systemctl disable triggerhappy || true
systemctl disable hciuart || true
systemctl disable systemd-timesyncd || true
# No unattended firmware changes; /boot/firmware is read-only anyway.
# EEPROM updates are a manual step (docs/first-boot-checklist.md).
systemctl disable rpi-eeprom-update || true

# Passwords are profile-specific (stage-decksmithos-dev / -release); none are set here.
usermod -aG audio,video,input,render,plugdev "${FIRST_USER_NAME}" || true

# The initramfs is rebuilt by 03-display-profile after the Plymouth theme is complete.
echo "MODULES=most" >/etc/initramfs-tools/conf.d/99local
EOF

for unit in \
    apt-daily.service \
    apt-daily.timer \
    apt-daily-upgrade.service \
    apt-daily-upgrade.timer
do
    on_chroot <<EOF
systemctl disable "${unit}" >/dev/null 2>&1 || true
systemctl mask "${unit}" >/dev/null 2>&1 || true
EOF
done

if [ -f remove-packages ]; then
    echo "Removing unnecessary packages"
    on_chroot <<EOF
apt -y --allow-remove-essential purge `xargs -a remove-packages` || true
apt -y autoremove --purge
EOF
fi

echo "Preparing /storage"
mkdir -p ${ROOTFS_DIR}/storage
rm -fr ${ROOTFS_DIR}/var/log/*

# Display-specific configuration is applied by ../03-display-profile.

# Persistent journal on /storage (journalctl -b -1 after a restart or power off).
install -v -d -m 755 "${ROOTFS_DIR}/etc/systemd/journald.conf.d"
install -v -m 644 files/journald-decksmithos.conf "${ROOTFS_DIR}/etc/systemd/journald.conf.d/50-decksmithos.conf"

# Clock: saved on /storage at shutdown and every 15 minutes, restored at boot if
# the clock is behind (no RTC battery, or a battery that ran flat).
install -v -m 755 files/decksmithos-clock "${ROOTFS_DIR}/usr/local/sbin/decksmithos-clock"
install -v -m 644 files/decksmithos-clock.service files/decksmithos-clock-save.service \
  files/decksmithos-clock-save.timer "${ROOTFS_DIR}/etc/systemd/system/"
# Time zone: chosen in the system menu, saved on /storage, applied at boot
# (the image itself stays on TIMEZONE_DEFAULT).
install -v -m 755 files/decksmithos-timezone "${ROOTFS_DIR}/usr/local/sbin/decksmithos-timezone"
install -v -m 644 files/decksmithos-timezone.service "${ROOTFS_DIR}/etc/systemd/system/"
on_chroot <<CHROOT
systemctl enable decksmithos-clock.service decksmithos-clock-save.timer decksmithos-timezone.service
CHROOT
