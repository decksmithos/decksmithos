#!/bin/bash
# DecksmithOS development profile: wired LAN (DHCP), SSH, known credentials and
# root console access for debugging. Nothing here may reach the release image.
set -Eeuo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

# Development-only credentials (AGENTS.md section 4). Never used in release.
DEV_PASSWORD="decksmithos"

echo "Configuring DecksmithOS dev runtime"
echo "${TARGET_HOSTNAME}" > "${ROOTFS_DIR}/etc/hostname"
echo "127.0.0.1 localhost" > "${ROOTFS_DIR}/etc/hosts"
echo "127.0.1.1 ${TARGET_HOSTNAME}" >> "${ROOTFS_DIR}/etc/hosts"

sed -i 's/^#NAutoVTs=6/NAutoVTs=1/' "${ROOTFS_DIR}/etc/systemd/logind.conf"

# Root autologin on the tty1 console for debugging.
mkdir -p "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
cat > "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --noreset %I $TERM
EOF

on_chroot <<EOF
echo "${FIRST_USER_NAME}:${DEV_PASSWORD}" | chpasswd
echo "root:${DEV_PASSWORD}" | chpasswd
systemctl enable ssh
EOF

# eth0 DHCP in the background (dhcpcd-base). Not through ifupdown: "auto eth0"
# held network.target, and with it systemd-user-sessions, nodm and Mixxx, until
# a lease arrived (or dhcpcd gave up). The release image has no eth0 config.
install -m 644 files/decksmithos-dhcp.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-dhcp.service"
on_chroot <<EOF
systemctl enable decksmithos-dhcp.service
EOF

# NTP once the lease arrives (dhcpcd's timesyncd hook passes DHCP NTP servers).
# A synchronized clock is written to the RTC by the kernel every 11 minutes.
# The release image has no network and keeps timesyncd disabled.
on_chroot <<EOF
systemctl enable systemd-timesyncd.service
EOF

# Trusted SSH key for dj and root (debugging over the wired LAN).
for home in "/home/${FIRST_USER_NAME}" /root; do
  install -d -m 700 "${ROOTFS_DIR}${home}/.ssh"
  install -m 600 files/authorized_keys "${ROOTFS_DIR}${home}/.ssh/authorized_keys"
done
on_chroot <<EOF
chown -R "${FIRST_USER_NAME}:${FIRST_USER_NAME}" "/home/${FIRST_USER_NAME}/.ssh"
chown -R root:root /root/.ssh
EOF

# VNC on the running X session (x11vnc, installed via 00-packages). VNC passwords
# are limited to 8 characters, so the effective password is "decksmit".
install -m 644 files/decksmithos-x11vnc.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-x11vnc.service"
on_chroot <<EOF
x11vnc -storepasswd "${DEV_PASSWORD}" /etc/x11vnc.pass
chmod 600 /etc/x11vnc.pass
systemctl enable decksmithos-x11vnc.service
EOF

# SSH host keys persist on /storage (the root filesystem is read-only).
install -m 755 files/decksmithos-ssh-hostkeys "${ROOTFS_DIR}/usr/local/sbin/decksmithos-ssh-hostkeys"
install -m 644 files/decksmithos-ssh-hostkeys.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-ssh-hostkeys.service"
on_chroot <<EOF
systemctl enable decksmithos-ssh-hostkeys.service
EOF

mkdir -p "${ROOTFS_DIR}/etc/ssh/sshd_config.d"
cat > "${ROOTFS_DIR}/etc/ssh/sshd_config.d/99local.conf" <<'EOF'
# DecksmithOS dev profile only.
PermitRootLogin yes
PasswordAuthentication yes
EOF

on_chroot > "${ROOTFS_DIR}/../packages" <<EOF
dpkg -l
EOF
