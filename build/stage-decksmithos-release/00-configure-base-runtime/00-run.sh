#!/bin/bash
#set -Eeuo pipefail

echo "Configuring DecksmithOS release runtime"
echo "${TARGET_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.0.1 localhost" > "${ROOTFS_DIR}/etc/hosts"
echo "127.0.1.1 ${TARGET_HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"

on_chroot <<EOF
systemctl disable bluetooth || true
systemctl disable avahi-daemon || true
systemctl disable triggerhappy || true
systemctl disable hciuart || true
systemctl disable networking || true
systemctl disable systemd-timesyncd || true
EOF

echo "Disabling apt runtime"
rm -rf ${ROOTFS_DIR}/var/lib/apt
rm -rf ${ROOTFS_DIR}/var/cache/apt
rm -rf ${ROOTFS_DIR}/var/log/apt

echo "Removing documentation"
rm -rf ${ROOTFS_DIR}/usr/share/man
rm -rf ${ROOTFS_DIR}/usr/share/doc
rm -rf ${ROOTFS_DIR}/usr/share/info
rm -rf ${ROOTFS_DIR}/usr/share/lintian
rm -rf ${ROOTFS_DIR}/usr/share/linda
rm -rf ${ROOTFS_DIR}/var/cache/*

echo "Removing locales"
rm -rf ${ROOTFS_DIR}/usr/share/locale/*
rm -rf ${ROOTFS_DIR}/usr/share/i18n/*

echo "Removing network and bluetouth related modules"
rm -rf ${ROOTFS_DIR}/lib/modules/*/kernel/drivers/net/wireless
rm -rf ${ROOTFS_DIR}/lib/modules/*/kernel/drivers/bluetooth
rm -rf ${ROOTFS_DIR}/lib/modules/*/kernel/net

echo "Applying release profile"
on_chroot <<EOF
passwd -l "${FIRST_USER_NAME}" || true
passwd -l "root" || true

systemctl disable "ssh" || true
systemctl mask "ssh" || true

apt -y --allow-remove-essential purge \
  apt \
  apt-listchanges \
  apt-utils \
  aptitude \
  curl \
  vim-common \
  vim-tiny \
  wget \
  openssh-server \
  openssh-sftp-server \
  iproute2 \
  isc-dhcp-client
  dhcpcd-base \
  netbase \
  iputils-arping \
  iputils-ping \
  htop \
  strace \
  mc \
  mingetty \
  gpm \
  ifupdown || true
apt -y autoremove --purge

EOF

on_chroot > ${ROOTFS_DIR}/../packages <<EOF
dpkg -l
EOF

echo "Clean rootfs"
rm -rf ${ROOTFS_DIR}/etc/ssh
rm -rf ${ROOTFS_DIR}/mnt
rm -rf ${ROOTFS_DIR}/opt
rm -rf ${ROOTFS_DIR}/srv
rm -rf ${ROOTFS_DIR}/usr/games
rm -rf ${ROOTFS_DIR}/usr/src
rm -rf ${ROOTFS_DIR}/var/backups
rm -rf ${ROOTFS_DIR}/var/cache
rm -rf ${ROOTFS_DIR}/var/local
rm -rf ${ROOTFS_DIR}/var/mail
rm -rf ${ROOTFS_DIR}/var/opt
rm -rf ${ROOTFS_DIR}/var/spool
