#!/bin/bash
#set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_TOUCH_PRODUCT="${DECKSMITHOS_SPI_TOUCH_PRODUCT:-}"
SPI_FB="${DECKSMITHOS_SPI_FB:-}"

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

mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.mixxx
install -v -m 644 files/mixxx.cfg "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.mixxx/mixxx.cfg"
install -v -m 644 files/soundconfig.xml "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.mixxx/soundconfig.xml"

on_chroot <<EOF
chmod +x /home/${FIRST_USER_NAME}/.xsession
chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}/
EOF

#echo "Option \"AutoAddGPU\" \"false\"" > ${ROOTFS_DIR}/etc/X11/xorg.conf

mkdir -p ${ROOTFS_DIR}/etc/X11/xorg.conf.d
install -v -m 644 files/45-evdev.conf "${ROOTFS_DIR}/etc/X11/xorg.conf.d/45-evdev.conf"

if [ "${DISPLAY_PROFILE}" == "spi35" ]; then
  echo "Writing Xorg fbdev configuration for SPI primary display"

  cat > ${ROOTFS_DIR}/etc/X11/xorg.conf.d/98-spi-screen.conf <<EOF
Section "Device"
    Identifier  "DecksmithOS SPI Screen"
    Driver      "fbturbo"
    Option      "fbdev" "${SPI_FB}"
    Option      "SwapbuffersWait" "true"
EndSection
EOF

  cat > ${ROOTFS_DIR}/etc/X11/xorg.conf.d/99-calibration.conf <<EOF
Section "InputClass"
    Identifier      "DecksmithOS SPI Touch Calibration"
    MatchProduct    "${SPI_TOUCH_PRODUCT}"
    Option          "Calibration" "3932 300 294 3801"
    Option          "SwapAxes" "1"
    Option          "EmulateThirdButton" "1"
    Option          "EmulateThirdButtonTimeout" "1000"
    Option          "EmulateThirdButtonMoveThreshold" "300"
EndSection
EOF
fi
