#!/bin/bash
# Apply the selected display profile (DECKSMITHOS_PRIMARY_DISPLAY) to the target rootfs.
#
# Each profile lives in files/<profile>/ and groups every display-specific layer
# (AGENTS.md section 15): firmware overlay (config.txt), kernel console (cmdline.txt,
# consumed by build/postprocess.sh), Xorg output/input, and Plymouth.
set -Eeuo pipefail

DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"
PROFILE_DIR="files/${DISPLAY_PROFILE}"

if [[ -z "${DISPLAY_PROFILE}" || ! -d "${PROFILE_DIR}" ]]; then
  echo "ERROR: unknown display profile '${DISPLAY_PROFILE}'; available: $(ls files)" >&2
  exit 1
fi

echo "Applying display profile: ${DISPLAY_PROFILE}"

BOOT_CONFIG="${ROOTFS_DIR}/boot/firmware/config.txt"
[[ -f "${BOOT_CONFIG}" ]] || { echo "ERROR: ${BOOT_CONFIG} not found" >&2; exit 1; }

# --- Firmware overlay ---------------------------------------------------------
if [[ -f "${PROFILE_DIR}/config.txt" ]]; then
  cat "${PROFILE_DIR}/config.txt" >> "${BOOT_CONFIG}"
fi

if [[ "${DISPLAY_PROFILE}" == "spi35" ]]; then
  # Unverified on CM5 (legacy settings carried over from the Pi 4 experiments).
  SPI_DTO="${DECKSMITHOS_SPI_DTO:?DECKSMITHOS_SPI_DTO not set}"
  SPI_ROTATION="${DECKSMITHOS_SPI_ROTATION:-0}"
  cat >> "${BOOT_CONFIG}" <<EOF

# Display profile: spi35 (Waveshare 3.5" SPI) -- UNVERIFIED on CM5
dtparam=spi=on
dtoverlay=${SPI_DTO}
display_rotate=${SPI_ROTATION}
hdmi_force_hotplug=1
max_usb_current=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt 480 320 60 6 0 0 0
hdmi_drive=2
EOF
fi

# --- Xorg output / input --------------------------------------------------------
mkdir -p "${ROOTFS_DIR}/etc/X11/xorg.conf.d"
if [[ -d "${PROFILE_DIR}/xorg.conf.d" ]]; then
  for conf in "${PROFILE_DIR}"/xorg.conf.d/*.conf; do
    install -v -m 644 "${conf}" "${ROOTFS_DIR}/etc/X11/xorg.conf.d/"
  done
fi

if [[ "${DISPLAY_PROFILE}" == "spi35" ]]; then
  SPI_FB="${DECKSMITHOS_SPI_FB:-/dev/fb1}"
  SPI_TOUCH_PRODUCT="${DECKSMITHOS_SPI_TOUCH_PRODUCT:-}"
  cat > "${ROOTFS_DIR}/etc/X11/xorg.conf.d/98-spi-screen.conf" <<EOF
Section "Device"
    Identifier  "DecksmithOS SPI Screen"
    Driver      "fbturbo"
    Option      "fbdev" "${SPI_FB}"
    Option      "SwapbuffersWait" "true"
EndSection
EOF
  cat > "${ROOTFS_DIR}/etc/X11/xorg.conf.d/99-calibration.conf" <<EOF
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

# --- Touch device name for decksmithos-touch / the touch overlay ---------------------
mkdir -p "${ROOTFS_DIR}/etc/decksmithos"
if [[ -f "${PROFILE_DIR}/touch.conf" ]]; then
  install -v -m 644 "${PROFILE_DIR}/touch.conf" "${ROOTFS_DIR}/etc/decksmithos/touch.conf"
elif [[ "${DISPLAY_PROFILE}" == "spi35" ]]; then
  echo "TOUCH_DEVICE=\"${DECKSMITHOS_SPI_TOUCH_PRODUCT:-}\"" > "${ROOTFS_DIR}/etc/decksmithos/touch.conf"
fi

# --- Plymouth ---------------------------------------------------------------------
THEME_DIR="${ROOTFS_DIR}/usr/share/plymouth/themes/decksmithos"
mkdir -p "${ROOTFS_DIR}/etc/plymouth" "${THEME_DIR}"
install -v -m 644 "${PROFILE_DIR}/plymouth/plymouthd.conf" "${ROOTFS_DIR}/etc/plymouth/plymouthd.conf"
install -v -m 644 "${PROFILE_DIR}/plymouth/decksmithos.script" "${THEME_DIR}/decksmithos.script"

# The theme is embedded in the initramfs, so rebuild it after installing the profile.
on_chroot <<EOF
plymouth-set-default-theme decksmithos
update-initramfs -k all -u
EOF
