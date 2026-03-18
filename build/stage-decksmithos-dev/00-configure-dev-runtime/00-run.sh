#!/bin/bash
#set -Eeuo pipefail

PROFILE="${DECKSMITHOS_PROFILE:-dev}"

echo "Configuring DecksmithOS dev runtime"
echo "${TARGET_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.0.1 localhost" > "${ROOTFS_DIR}/etc/hosts"
echo "127.0.1.1 ${TARGET_HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"

sed -i 's/^#NAutoVTs=6/NAutoVTs=1/' "${ROOTFS_DIR}/etc/systemd/logind.conf"

mkdir -p "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/"
echo >"${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --noreset %I 38400 linux
EOF

on_chroot <<EOF
systemctl enable ssh
systemctl enable dhcpcd
EOF

echo 'PermitRootLogin yes' > ${ROOTFS_DIR}/etc/ssh/sshd_config.d/99local.conf
echo 'PasswordAuthentication yes' >> ${ROOTFS_DIR}/etc/ssh/sshd_config.d/99local.conf

on_chroot > ${ROOTFS_DIR}/../packages <<EOF
dpkg -l
EOF
