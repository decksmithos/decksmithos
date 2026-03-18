#!/bin/bash
#set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_DTO="${DECKSMITHOS_SPI_DTO:-}"
SPI_ROTATION="${DECKSMITHOS_SPI_ROTATION:-}"

PROFILE="${DECKSMITHOS_PROFILE:-release}"

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
install -v -m 644 files/interfaces-eth0 "${ROOTFS_DIR}/etc/network/interfaces.d/eth0"

mkdir -p "${ROOTFS_DIR}/etc/plymouth"
install -v -m 644 files/plymouthd.conf "${ROOTFS_DIR}/etc/plymouth/plymouthd.conf"
mkdir -p "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos"
install -v -m 644 files/decksmithos.plymouth "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos/decksmithos.plymouth"
install -v -m 644 files/decksmithos.script "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos/decksmithos.script"
install -v -m 644 files/splash.png "${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos/splash.png"

install -v -m 644 files/decksmithos-storage-init.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-storage-init.service"
install -v -m 755 files/decksmithos-init-storage "${ROOTFS_DIR}/usr/local/sbin/decksmithos-init-storage"
install -v -m 755 files/decksmithos-mixxx "${ROOTFS_DIR}/usr/local/bin/decksmithos-mixxx"

sed -i 's/^NODM_ENABLED=.*/NODM_ENABLED=true/' ${ROOTFS_DIR}/etc/default/nodm
sed -i "s/^NODM_USER=.*/NODM_USER=${FIRST_USER_NAME}/" ${ROOTFS_DIR}/etc/default/nodm
#sed -i "s#^NODM_XSESSION=.*#NODM_XSESSION=/home/${FIRST_USER_NAME}/.xsession#" ${ROOTFS_DIR}/etc/default/nodm

on_chroot <<EOF
systemctl enable decksmithos-storage-init.service
systemctl enable nodm

systemctl disable serial-getty@ttyAMA0.service || true
systemctl disable bluetooth || true
systemctl disable avahi-daemon || true
systemctl disable triggerhappy || true
systemctl disable hciuart || true
systemctl disable systemd-timesyncd || true

if [ -d /usr/share/plymouth/themes/decksmithos ]; then
    plymouth-set-default-theme decksmithos || true
fi

echo "${FIRST_USER_NAME}:decksmithos" | chpasswd
usermod -aG audio,video,input,render,plugdev "${FIRST_USER_NAME}" || true

echo "root:decksmithos" | chpasswd

echo "MODULES=most" >/etc/initramfs-tools/conf.d/99local
update-initramfs -k all -u
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

echo "DECKSMITHOS_PRIMARY_DISPLAY: ${DISPLAY_PROFILE}"
if [ "${DISPLAY_PROFILE}" == "spi35" ]; then
  echo "Applying SPI 3.5 primary display configuration"

  BOOT_CONFIG=""
  if [ -f ${ROOTFS_DIR}/boot/firmware/config.txt ]; then
    BOOT_CONFIG="${ROOTFS_DIR}/boot/firmware/config.txt"
  elif [ -f ${ROOTFS_DIR}/boot/config.txt ]; then
    BOOT_CONFIG="${ROOTFS_DIR}/boot/config.txt"
  fi

  if [ -z "${BOOT_CONFIG}" ]; then
    echo "ERROR: boot config.txt not found" >&2
    exit 1
  fi

  cat >> "${BOOT_CONFIG}" <<EOF

# enable SPI for 3.5 display
dtparam=spi=on
dtoverlay=${SPI_DTO}
display_rotate=${SPI_ROTATION}
hdmi_force_hotplug=1
max_usb_current=1
hdmi_group=2
hdmi_mode=1
hdmi_mode=87
hdmi_cvt 480 320 60 6 0 0 0
hdmi_drive=2
EOF
fi
