#!/bin/bash
set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
SPI_TOUCH_PRODUCT="${DECKSMITHOS_SPI_TOUCH_PRODUCT:-ADS7846 Touchscreen}"
SPI_FB="${DECKSMITHOS_SPI_FB:-/dev/fb1}"

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

unclutter -idle 0.2 -root &

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

mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/openbox
cat > ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/openbox/autostart <<EOF
xsetroot -solid black &
xset s off &
xset -dpms &
xset s noblank &
EOF

on_chroot <<EOF
chmod +x /home/${FIRST_USER_NAME}/.xsession
chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}/
EOF

cat > ${ROOTFS_DIR}/usr/local/bin/decksmithos-mixxx <<'EOF'
#!/bin/bash
set -euo pipefail

LOG_DIR="/storage/logs"
mkdir -p "${LOG_DIR}"

exec >>"${LOG_DIR}/mixxx.log" 2>&1

CORES="${DECKSMITHOS_CORES:-2,3}"
ARGS=(--fullscreen)

renice -n -5 $$ >/dev/null 2>&1 || true
exec taskset -c "${CORES}" mixxx "${ARGS[@]}"
EOF

chmod +x ${ROOTFS_DIR}/usr/local/bin/decksmithos-mixxx

echo "Option \"AutoAddGPU\" \"false\"" > ${ROOTFS_DIR}/etc/X11/xorg.conf

mkdir -p ${ROOTFS_DIR}/etc/X11/xorg.conf.d

if [[ "${DISPLAY_PROFILE}" == "spi35" ]]; then
  echo "Writing Xorg fbdev configuration for SPI primary display"

  cat > ${ROOTFS_DIR}/etc/X11/xorg.conf.d/98-spi-screen.conf <<EOF
Section "Device"
    Identifier  "DecksmithOS SPI Screen"
    Driver      "fbturbo"
    Option      "fbdev" "${SPI_FB}"
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
