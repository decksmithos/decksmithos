#!/usr/bin/env bash
# Make a signed DecksmithOS update file from a built image (slot A of
# build/output/decksmithos-<profile>.img), for decksmithos-update on the device.
#
#   build/make-update.sh [image]        default: build/output/decksmithos-release.img
#
# Output: build/output/decksmithos-<profile>-<version>.update
# Copy it to the root of a USB stick as "decksmithos.update"; the system menu
# (short press on the power button) offers to install it into the inactive slot.
#
# Format (see decksmithos-update): uncompressed tar of
#   manifest, manifest.sig, boot.tar.zst, rootfs.tar.zst
#
# Signing uses the DecksmithOS update key (ssh-keygen -Y sign, namespace
# decksmithos-update). Its public half is installed on the device as
# /etc/decksmithos/update-signers. The private key never enters the repository.
#   DECKSMITHOS_SIGN_KEY       default ~/.ssh/decksmithos_ed25519
#   DECKSMITHOS_SIGN_PASSFILE  file holding the key's passphrase (optional,
#                              default ~/.ssh/decksmithos.pass; asked if absent)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${1:-${SCRIPT_DIR}/output/decksmithos-release.img}"
SIGN_KEY="${DECKSMITHOS_SIGN_KEY:-${HOME}/.ssh/decksmithos_ed25519}"
SIGN_PASSFILE="${DECKSMITHOS_SIGN_PASSFILE:-${HOME}/.ssh/decksmithos.pass}"
NAMESPACE="decksmithos-update"
ZSTD_LEVEL="${ZSTD_LEVEL:-19}"

die() { echo "make-update: ERROR: $*" >&2; exit 1; }
log() { echo "make-update: $*"; }

[[ -f "${IMAGE}" ]] || die "image not found: ${IMAGE}"
[[ -f "${SIGN_KEY}" ]] || die "signing key not found: ${SIGN_KEY}"
for t in zstd ssh-keygen tar sha256sum losetup; do
  command -v "${t}" >/dev/null || die "missing tool: ${t}"
done

STAGE="$(mktemp -d "${SCRIPT_DIR}/update-staging.XXXXXX")"
MNT="${STAGE}/mnt"
LOOP=""
cleanup() {
  sudo umount "${MNT}/boot" 2>/dev/null || true
  sudo umount "${MNT}/root" 2>/dev/null || true
  [[ -n "${LOOP}" ]] && sudo losetup -d "${LOOP}" 2>/dev/null || true
  sudo rm -rf "${STAGE}"
}
trap cleanup EXIT

LOOP="$(sudo losetup --find --show --partscan --read-only "${IMAGE}")"
sudo udevadm settle || true
mkdir -p "${MNT}/boot" "${MNT}/root"
sudo mount -o ro "${LOOP}p2" "${MNT}/boot"
sudo mount -o ro "${LOOP}p4" "${MNT}/root"
[[ "$(sudo blkid -p -o value -s PART_ENTRY_NAME "${LOOP}p4")" == rootfs_A ]] || die "${IMAGE} is not a DecksmithOS A/B image"
[[ -f "${MNT}/boot/decksmithos-version.txt" ]] || die "no decksmithos-version.txt in the image"

version="$(sed -n 's/^version=//p' "${MNT}/boot/decksmithos-version.txt")"
profile="$(sed -n 's/^profile=//p' "${MNT}/boot/decksmithos-version.txt")"
bootloader="$(sudo find "${MNT}/root/usr/lib/firmware/raspberrypi/bootloader-2712/default" -name 'pieeprom-*.bin' -printf '%f\n' 2>/dev/null \
  | sort | tail -n1 | sed 's/^pieeprom-\(.*\)\.bin$/\1/')"
log "image ${IMAGE}: version ${version}, profile ${profile}"

log "packing boot partition"
sudo tar -C "${MNT}/boot" -cf - . | zstd -q -T0 -"${ZSTD_LEVEL}" > "${STAGE}/boot.tar.zst"
log "packing root filesystem (zstd -${ZSTD_LEVEL}, this takes a while)"
sudo tar -C "${MNT}/root" --numeric-owner --xattrs --xattrs-include='*' --acls -cf - . \
  | zstd -q -T0 -"${ZSTD_LEVEL}" > "${STAGE}/rootfs.tar.zst"
rootfs_kib="$(sudo du -sk --apparent-size "${MNT}/root" | awk '{print $1}')"

{
  echo "format=1"
  grep -E '^[a-z_0-9]+=[^[:space:]]*$' "${MNT}/boot/decksmithos-version.txt"
  echo "bootloader=${bootloader:-unknown}"
  echo "boot_sha256=$(sha256sum "${STAGE}/boot.tar.zst" | awk '{print $1}')"
  echo "rootfs_sha256=$(sha256sum "${STAGE}/rootfs.tar.zst" | awk '{print $1}')"
  echo "rootfs_kib=${rootfs_kib}"
} > "${STAGE}/manifest"
cat "${STAGE}/manifest"

log "signing the manifest with ${SIGN_KEY}"
if [[ -r "${SIGN_PASSFILE}" ]]; then
  askpass="${STAGE}/askpass"
  printf '#!/bin/sh\ncat "%s"\n' "${SIGN_PASSFILE}" > "${askpass}"
  chmod 700 "${askpass}"
  SSH_ASKPASS="${askpass}" SSH_ASKPASS_REQUIRE=force \
    ssh-keygen -q -Y sign -f "${SIGN_KEY}" -n "${NAMESPACE}" "${STAGE}/manifest" </dev/null
else
  ssh-keygen -q -Y sign -f "${SIGN_KEY}" -n "${NAMESPACE}" "${STAGE}/manifest"
fi
[[ -s "${STAGE}/manifest.sig" ]] || die "signing failed"

# Check against the signer file the device uses.
signers="${SCRIPT_DIR}/stage-decksmithos/04-system-menu/files/update-signers"
ssh-keygen -Y verify -f "${signers}" -I decksmithos -n "${NAMESPACE}" \
  -s "${STAGE}/manifest.sig" < "${STAGE}/manifest" >/dev/null \
  || die "signature does not verify against ${signers} (wrong key?)"

out="${SCRIPT_DIR}/output/decksmithos-${profile}-${version}.update"
tar -C "${STAGE}" --owner=0 --group=0 -cf "${STAGE}/out.update" manifest manifest.sig boot.tar.zst rootfs.tar.zst
sudo mv -f "${STAGE}/out.update" "${out}"
sudo chmod 644 "${out}"
log "created ${out} ($(du -h "${out}" | cut -f1))"
log "copy it to a USB stick as: decksmithos.update"
