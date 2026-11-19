#!/bin/bash
# DecksmithOS release profile: minimal, no network services, no interactive logins.
# Order matters: purge packages while apt still exists, then delete other files.
# apt itself is removed after pi-gen's export (see build/postprocess.sh).
set -Eeuo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

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
systemctl disable ssh || true
systemctl mask ssh || true
systemctl disable sshswitch || true
systemctl mask sshswitch || true

# The release image keeps no usable passwords: dj (generated FIRST_USER_PASS
# from build.sh) and root are both locked.
passwd -l "${FIRST_USER_NAME}"
passwd -l root
EOF

echo "Purging development and network packages"
# apt aborts the whole purge if one name is unknown, so only pass installed packages.
# netbase stays: purging it removes python3, and with it openbox and rpi-eeprom.
on_chroot <<'EOF'
set -e
PURGE="
  aptitude curl wget vim-common vim-tiny
  openssh-server openssh-sftp-server
  iproute2 isc-dhcp-client dhcpcd-base
  iputils-arping iputils-ping ifupdown
  htop strace mc mingetty gpm
"
INSTALLED="$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' ${PURGE} 2>/dev/null | awk '$1 == "ii" {print $2}')"
echo "Purging: ${INSTALLED}"
if [ -n "${INSTALLED}" ]; then
  apt-get -y --allow-remove-essential purge ${INSTALLED}
fi
apt-get -y autoremove --purge
apt-get clean
EOF

# Purging also removes packages that depend on the purged ones; make sure the
# appliance itself survived.
on_chroot <<'EOF'
set -e
missing=""
for p in mixxx mixxx-data xserver-xorg-core nodm openbox plymouth udev udisks2 \
         sqlite3 parted fdisk e2fsprogs dosfstools rpi-eeprom raspi-utils python3 overlayroot \
         sudo python3-tk python3-xlib xcompmgr xinput unclutter-xfixes xinput-calibrator \
         zstd openssh-client flashrom; do
  dpkg-query -W -f='${db:Status-Abbrev}' "${p}" 2>/dev/null | grep -q '^ii' || missing="${missing} ${p}"
done
if [ -n "${missing}" ]; then
  echo "ERROR: release purge removed required packages:${missing}" >&2
  exit 1
fi
EOF

echo "Recording final package list"
on_chroot > "${ROOTFS_DIR}/../packages" <<EOF
dpkg -l
EOF

# apt itself is removed by build/postprocess.sh: pi-gen's export-image still
# needs apt-get (userconf-pi, dist-upgrade) after this stage.

echo "Removing documentation"
rm -rf "${ROOTFS_DIR}/usr/share/man" \
       "${ROOTFS_DIR}/usr/share/doc" \
       "${ROOTFS_DIR}/usr/share/info" \
       "${ROOTFS_DIR}/usr/share/lintian" \
       "${ROOTFS_DIR}/usr/share/linda"

echo "Removing locales"
rm -rf "${ROOTFS_DIR}"/usr/share/locale/* "${ROOTFS_DIR}"/usr/share/i18n/*

echo "Removing network and bluetooth related modules"
rm -rf "${ROOTFS_DIR}"/lib/modules/*/kernel/drivers/net/wireless \
       "${ROOTFS_DIR}"/lib/modules/*/kernel/drivers/bluetooth \
       "${ROOTFS_DIR}"/lib/modules/*/kernel/net
# Keep module dependency data consistent with the removed modules.
on_chroot <<'EOF'
for kdir in /lib/modules/*; do
  depmod -a "$(basename "${kdir}")"
done
EOF

echo "Clean rootfs"
# Empty /var/cache but keep the directory and apt's cache: pi-gen's export-image
# still runs apt-get; postprocess.sh removes apt and its cache afterwards.
find "${ROOTFS_DIR}/var/cache" -mindepth 1 -maxdepth 1 ! -name apt -exec rm -rf {} +
rm -rf "${ROOTFS_DIR}/etc/ssh" \
       "${ROOTFS_DIR}/root/.ssh" \
       "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.ssh" \
       "${ROOTFS_DIR}/mnt" \
       "${ROOTFS_DIR}/opt" \
       "${ROOTFS_DIR}/srv" \
       "${ROOTFS_DIR}/usr/games" \
       "${ROOTFS_DIR}/usr/src" \
       "${ROOTFS_DIR}/var/backups" \
       "${ROOTFS_DIR}/var/local" \
       "${ROOTFS_DIR}/var/mail" \
       "${ROOTFS_DIR}/var/opt" \
       "${ROOTFS_DIR}/var/spool"
