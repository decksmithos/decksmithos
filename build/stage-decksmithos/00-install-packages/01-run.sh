#!/bin/bash
# Install the pinned Mixxx packages that build.sh placed in files/mixxx/
# (see build/mixxx/README.md). Dependencies come from the base release.
set -Eeuo pipefail
: "${ROOTFS_DIR:?ROOTFS_DIR must point at the target rootfs}"

MODE="${DECKSMITHOS_MIXXX:-release}"

if [[ "${MODE}" == "debian" ]]; then
  echo "WARNING: installing the base release's mixxx package (DECKSMITHOS_MIXXX=debian)"
  on_chroot <<EOF2
apt-get install -y --no-install-recommends mixxx
EOF2
  exit 0
fi

shopt -s nullglob
debs=(files/mixxx/*.deb)
shopt -u nullglob
(( ${#debs[@]} > 0 )) || { echo "ERROR: no Mixxx packages in files/mixxx (DECKSMITHOS_MIXXX=${MODE})" >&2; exit 1; }

TMP_IN_ROOTFS="/tmp/decksmithos-mixxx-debs"
install -d "${ROOTFS_DIR}${TMP_IN_ROOTFS}"
install -m 644 "${debs[@]}" "${ROOTFS_DIR}${TMP_IN_ROOTFS}/"

on_chroot <<EOF2
apt-get install -y --no-install-recommends ${TMP_IN_ROOTFS}/*.deb
# Never replace the pinned build with the archive's version.
apt-mark hold mixxx mixxx-data
dpkg-query -W -f '\${Package} \${Version}\n' mixxx mixxx-data
EOF2
rm -rf "${ROOTFS_DIR}${TMP_IN_ROOTFS}"
