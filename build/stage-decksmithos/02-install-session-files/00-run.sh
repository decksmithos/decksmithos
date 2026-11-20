#!/bin/bash
#set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_FB="${DECKSMITHOS_SPI_FB:-}"

: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

echo "Installing DecksmithOS session files"

cat > ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.xsession <<EOF
#!/bin/sh

# First thing: the DecksmithOS logo as the X background (the same band of the
# splash that Plymouth shows, scaled the same way: proportionally to the
# screen width). Mixxx starts over it; it also shows while Mixxx restarts.
hsetroot -solid black -full /usr/share/decksmithos/splash-band.png

xset s off
xset -dpms
xset s noblank

if [ "${DISPLAY_PROFILE}" = "spi35" ]; then
  export FRAMEBUFFER=${SPI_FB}
fi

# Touch: no mouse cursor. Hidden from the start and on every touch; a real
# mouse (dev) shows it again while it moves.
unclutter-xfixes --start-hidden --hide-on-touch --timeout 2 &

openbox-session &

# Touchscreen calibration saved on /storage (decksmithos-touch calibrate).
/usr/local/bin/decksmithos-touch apply || true

# Dev profile: show touches (compositor + overlay) and the dev-mode notice
# once Mixxx is on screen.
if [ "\$(cat /etc/decksmithos/profile 2>/dev/null)" = "dev" ]; then
  # After Mixxx is on screen: the compositor would paint over the splash.
  (/usr/local/bin/decksmithos-mixxx-ui wait-window 120; /usr/local/bin/decksmithos-touch overlay on) &
  (/usr/local/bin/decksmithos-mixxx-ui wait-window 120; sleep 3; /usr/local/bin/decksmithos-dev-banner) &
fi

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

# The X session (xinit + ~/.xsession + Mixxx) as a systemd service with a login
# session for the user, instead of a display manager (nodm restarted its
# session on SIGTERM, which made every shutdown wait for a timeout).
install -v -m 644 files/decksmithos-session.service "${ROOTFS_DIR}/etc/systemd/system/decksmithos-session.service"
on_chroot <<CHROOT
systemctl enable decksmithos-session.service
systemctl set-default graphical.target
# tty1 belongs to the X session (splash handover on the same VT).
systemctl mask getty@tty1.service
CHROOT
install -v -m 755 files/decksmithos-splash-done "${ROOTFS_DIR}/usr/local/sbin/decksmithos-splash-done"
install -v -m 644 files/splash-band.png "${ROOTFS_DIR}/usr/share/decksmithos/splash-band.png"
