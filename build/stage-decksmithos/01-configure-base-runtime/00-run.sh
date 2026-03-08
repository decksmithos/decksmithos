#!/bin/bash
#set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_DTO="${DECKSMITHOS_SPI_DTO:-waveshare35b-v2}"
SPI_ROTATION="${DECKSMITHOS_SPI_ROTATION:-90}"

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

install -v -m 644 files/decksmithos-storage-init.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-storage-init.service"
install -v -m 755 files/decksmithos-init-storage "${ROOTFS_DIR}/usr/local/sbin/decksmithos-init-storage"

sed -i 's/^NODM_ENABLED=.*/NODM_ENABLED=true/' ${ROOTFS_DIR}/etc/default/nodm
sed -i "s/^NODM_USER=.*/NODM_USER=${FIRST_USER_NAME}/" ${ROOTFS_DIR}/etc/default/nodm
sed -i "s#^NODM_XSESSION=.*#NODM_XSESSION=/home/${FIRST_USER_NAME}/.xsession#" ${ROOTFS_DIR}/etc/default/nodm

on_chroot <<EOF
systemctl enable nodm

systemctl disable bluetooth || true
systemctl disable avahi-daemon || true
systemctl disable triggerhappy || true
systemctl disable hciuart || true
systemctl disable systemd-timesyncd || true

echo "${FIRST_USER_NAME}:decksmithos" | chpasswd
usermod -aG audio,video,input,render,plugdev "${FIRST_USER_NAME}" || true

echo "root:decksmithos" | chpasswd
EOF

#if [ -f remove-packages ]; then
#    echo "Removing unnecessary packages"
#    on_chroot <<EOF
#apt -y --allow-remove-essential purge `xargs -a remove-packages` || true
#apt -y autoremove --purge
#EOF
#fi

echo "Preparing /storage"
mkdir -p ${ROOTFS_DIR}/storage
rm -fr ${ROOTFS_DIR}/var/log/*

if [[ "${DISPLAY_PROFILE}" == "spi35" ]]; then
  echo "Applying SPI 3.5 primary display configuration"

  BOOT_CONFIG=""
  if [[ -f ${ROOTFS_DIR}/boot/firmware/config.txt ]]; then
    BOOT_CONFIG="${ROOTFS_DIR}/boot/firmware/config.txt"
  elif [[ -f ${ROOTFS_DIR}/boot/config.txt ]]; then
    BOOT_CONFIG="${ROOTFS_DIR}/boot/config.txt"
  fi

  if [[ -z "${BOOT_CONFIG}" ]]; then
    echo "ERROR: boot config.txt not found" >&2
    exit 1
  fi

  cat >> "${BOOT_CONFIG}" <<EOF

[all]
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
