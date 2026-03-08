#!/bin/bash
#set -Eeuo pipefail

PROFILE="${DECKSMITHOS_PROFILE:-dev}"

echo "Configuring DecksmithOS dev runtime"

echo "${TARGET_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"

echo "127.0.0.1 localhost" > "${ROOTFS_DIR}/etc/hosts"
echo "127.0.1.1 ${TARGET_HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"

on_chroot <<EOF
systemctl enable ssh
systemctl enable dhcpcd
EOF

sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' ${ROOTFS_DIR}/etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' ${ROOTFS_DIR}/etc/ssh/sshd_config

on_chroot > ${ROOTFS_DIR}/../packages <<EOF
dpkg -l
EOF
