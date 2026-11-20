#!/bin/bash
# System menu (power button), touch tools and the dev-mode notice.
#
#   power button short press -> decksmithos-menu (power off, restart, slots,
#                               touch calibration and overlay, dev actions)
#   power button long press  -> clean power off (decksmithos-powerd)
set -Eeuo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

echo "Installing DecksmithOS system menu"
install -v -m 755 files/decksmithos-powerd "${ROOTFS_DIR}/usr/local/sbin/decksmithos-powerd"
install -v -m 755 files/decksmithos-system "${ROOTFS_DIR}/usr/local/sbin/decksmithos-system"
# Signed system updates into the inactive slot (made by build/make-update.sh).
install -v -m 755 files/decksmithos-update "${ROOTFS_DIR}/usr/local/sbin/decksmithos-update"
install -v -d -m 755 "${ROOTFS_DIR}/etc/decksmithos"
install -v -m 644 files/update-signers "${ROOTFS_DIR}/etc/decksmithos/update-signers"
install -v -m 644 files/bootloader.conf "${ROOTFS_DIR}/etc/decksmithos/bootloader.conf"
install -v -m 755 files/decksmithos-menu "${ROOTFS_DIR}/usr/local/bin/decksmithos-menu"
install -v -m 755 files/decksmithos-touch "${ROOTFS_DIR}/usr/local/bin/decksmithos-touch"
install -v -m 755 files/decksmithos-touch-overlay "${ROOTFS_DIR}/usr/local/bin/decksmithos-touch-overlay"
install -v -m 755 files/decksmithos-dev-banner "${ROOTFS_DIR}/usr/local/bin/decksmithos-dev-banner"

install -v -m 644 files/decksmithos-powerd.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-powerd.service"
install -v -m 644 files/decksmithos-power.default "${ROOTFS_DIR}/etc/default/decksmithos-power"
install -v -d -m 755 "${ROOTFS_DIR}/etc/systemd/logind.conf.d"
install -v -m 644 files/logind-decksmithos-power.conf "${ROOTFS_DIR}/etc/systemd/logind.conf.d/decksmithos-power.conf"

sed "s/^dj /${FIRST_USER_NAME} /" files/sudoers-decksmithos-system > "${ROOTFS_DIR}/etc/sudoers.d/decksmithos-system"
chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/decksmithos-system"

on_chroot <<CHROOT
visudo -cf /etc/sudoers.d/decksmithos-system
systemctl enable decksmithos-powerd.service
CHROOT
