#!/usr/bin/env bash
# Sign an unsigned DecksmithOS update (made by make-update.sh --unsigned,
# e.g. in the build VM) with the update key of this user. No root needed.
#
#   build/sign-update.sh <decksmithos-<profile>-<version>.unsigned>
#
# Output: the same name with .update, next to it. The key and its passphrase
# file are the ones make-update.sh uses (DECKSMITHOS_SIGN_KEY,
# DECKSMITHOS_SIGN_PASSFILE); the signature is checked against the signer
# file the device uses before the update is written.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGN_KEY="${DECKSMITHOS_SIGN_KEY:-${HOME}/.ssh/decksmithos_ed25519}"
SIGN_PASSFILE="${DECKSMITHOS_SIGN_PASSFILE:-${HOME}/.ssh/decksmithos.pass}"
NAMESPACE="decksmithos-update"

die() { echo "sign-update: ERROR: $*" >&2; exit 1; }
log() { echo "sign-update: $*"; }

unsigned="${1:?usage: $0 <file.unsigned>}"
[[ -f "${unsigned}" && "${unsigned}" == *.unsigned ]] || die "not an .unsigned file: ${unsigned}"
[[ -f "${SIGN_KEY}" ]] || die "signing key not found: ${SIGN_KEY}"

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT
tar -C "${stage}" -xf "${unsigned}" manifest boot.tar.zst rootfs.tar.zst \
  || die "${unsigned} lacks manifest, boot.tar.zst or rootfs.tar.zst"

# The manifest must describe these archives
for part in boot rootfs; do
  want="$(sed -n "s/^${part}_sha256=//p" "${stage}/manifest")"
  have="$(sha256sum "${stage}/${part}.tar.zst" | awk '{print $1}')"
  [[ -n "${want}" && "${want}" == "${have}" ]] || die "${part}.tar.zst does not match the manifest"
done
cat "${stage}/manifest"

log "signing the manifest with ${SIGN_KEY}"
if [[ -r "${SIGN_PASSFILE}" ]]; then
  askpass="${stage}/askpass"
  printf '#!/bin/sh\ncat "%s"\n' "${SIGN_PASSFILE}" > "${askpass}"
  chmod 700 "${askpass}"
  SSH_ASKPASS="${askpass}" SSH_ASKPASS_REQUIRE=force \
    ssh-keygen -q -Y sign -f "${SIGN_KEY}" -n "${NAMESPACE}" "${stage}/manifest" </dev/null
else
  ssh-keygen -q -Y sign -f "${SIGN_KEY}" -n "${NAMESPACE}" "${stage}/manifest"
fi
[[ -s "${stage}/manifest.sig" ]] || die "signing failed"

signers="${SCRIPT_DIR}/stage-decksmithos/04-system-menu/files/update-signers"
ssh-keygen -Y verify -f "${signers}" -I decksmithos -n "${NAMESPACE}" \
  -s "${stage}/manifest.sig" < "${stage}/manifest" >/dev/null \
  || die "signature does not verify against ${signers} (wrong key?)"

out="${unsigned%.unsigned}.update"
tar -C "${stage}" --owner=0 --group=0 -cf "${out}.part" manifest manifest.sig boot.tar.zst rootfs.tar.zst
mv -f "${out}.part" "${out}"
chmod 644 "${out}"
log "created ${out} ($(du -h "${out}" | cut -f1))"
