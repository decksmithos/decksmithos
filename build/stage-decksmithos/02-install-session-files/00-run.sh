#!/bin/bash
#set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_FB="${DECKSMITHOS_SPI_FB:-}"

: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

echo "Installing DecksmithOS session files"

cat > ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.xsession <<EOF
#!/bin/sh

xset s off
xset -dpms
xset s noblank
xsetroot -solid black

if [ "${DISPLAY_PROFILE}" = "spi35" ]; then
  export FRAMEBUFFER=${SPI_FB}
fi

#unclutter -idle 0.2 -root &

if command -v plymouth >/dev/null 2>&1; then
  if plymouth --help 2>&1 | grep -q -- '--retain-splash'; then
    plymouth quit --retain-splash || true
  else
    plymouth quit || true
  fi
fi

openbox-session &
exec /usr/local/bin/decksmithos-mixxx
EOF

#mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/openbox
#cat > ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/openbox/autostart <<EOF
#xsetroot -solid black &
#xset s off &
#xset -dpms &
#xset s noblank &
#EOF

# Mixxx defaults: copied to /storage/config/mixxx by decksmithos-mixxx on first start.
mkdir -p "${ROOTFS_DIR}/usr/share/decksmithos/mixxx-defaults"
# Additional Mixxx skins (synced from mixxx/skins by build.sh). LateNight ships with Mixxx.
if [ -d files/skins ]; then
  for skin in files/skins/*/; do
    [ -f "${skin}skin.xml" ] || continue
    name="$(basename "${skin}")"
    rm -rf "${ROOTFS_DIR}/usr/share/mixxx/skins/${name}"
    cp -r "${skin}" "${ROOTFS_DIR}/usr/share/mixxx/skins/${name}"
    chmod -R u=rwX,go=rX "${ROOTFS_DIR}/usr/share/mixxx/skins/${name}"
    echo "Installed Mixxx skin: ${name}"
  done
else
  echo "WARNING: files/skins missing (run via build.sh); only built-in Mixxx skins installed"
fi

# soundconfig.xml is not shipped: decksmithos-mixxx generates it for the detected
# controller audio (a config without outputs makes Mixxx stop at a dialog).
install -v -m 644 files/mixxx.cfg "${ROOTFS_DIR}/usr/share/decksmithos/mixxx-defaults/mixxx.cfg"

on_chroot <<EOF
chmod +x /home/${FIRST_USER_NAME}/.xsession
chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}/
EOF

#echo "Option \"AutoAddGPU\" \"false\"" > ${ROOTFS_DIR}/etc/X11/xorg.conf

mkdir -p ${ROOTFS_DIR}/etc/X11/xorg.conf.d
install -v -m 644 files/45-evdev.conf "${ROOTFS_DIR}/etc/X11/xorg.conf.d/45-evdev.conf"

# Display-specific Xorg configuration is installed by ../03-display-profile.
