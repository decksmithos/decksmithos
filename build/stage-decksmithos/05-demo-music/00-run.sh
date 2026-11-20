#!/bin/bash
# Demo tracks for a freshly flashed device (see build/demo-music/fetch.sh).
# build.sh fills files/demo-library unless DECKSMITHOS_DEMO_MUSIC=0. They land
# in slot A only: make-update.sh leaves this directory out of update files, and
# decksmithos-init-storage copies it to /storage/library/Demo when it creates
# /storage on first boot.
set -Eeuo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

DEST="${ROOTFS_DIR}/usr/share/decksmithos/demo-library"
rm -rf "${DEST}"
if [[ -d files/demo-library ]] && [[ -n "$(ls -A files/demo-library)" ]]; then
  install -d -m 755 "${DEST}"
  cp -r files/demo-library/. "${DEST}/"
  chmod -R u=rwX,go=rX "${DEST}"
  chown -R root:root "${DEST}"
  echo "Installed demo tracks: $(du -sh "${DEST}" | cut -f1)"
else
  echo "No demo tracks (DECKSMITHOS_DEMO_MUSIC=0)"
fi
