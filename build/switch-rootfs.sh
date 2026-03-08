#!/usr/bin/env bash
set -Eeuo pipefail

BOOT_MOUNT="${BOOT_MOUNT:-/boot/firmware}"
CMDLINE_FILE=""

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "Run this script as root."
}

find_cmdline() {
  if [[ -f "${BOOT_MOUNT}/cmdline.txt" ]]; then
    CMDLINE_FILE="${BOOT_MOUNT}/cmdline.txt"
    return
  fi

  if [[ -f "${BOOT_MOUNT}/firmware/cmdline.txt" ]]; then
    CMDLINE_FILE="${BOOT_MOUNT}/firmware/cmdline.txt"
    return
  fi

  die "Could not find cmdline.txt under ${BOOT_MOUNT}"
}

get_partuuid_by_label() {
  local label="$1"
  blkid -L "${label}" -s PARTUUID -o value
}

current_root_partuuid() {
  tr -d '\n' < "${CMDLINE_FILE}" | sed -n 's/.*root=PARTUUID=\([^ ]*\).*/\1/p'
}

switch_to_slot() {
  local slot="$1"
  local target_label=""
  local target_partuuid=""
  local current_cmdline=""

  case "${slot}" in
    A|a) target_label="rootfs_A" ;;
    B|b) target_label="rootfs_B" ;;
    *) die "Usage: $0 [A|B]" ;;
  esac

  target_partuuid="$(get_partuuid_by_label "${target_label}")"
  [[ -n "${target_partuuid}" ]] || die "Could not resolve PARTUUID for ${target_label}"

  current_cmdline="$(tr -d '\n' < "${CMDLINE_FILE}")"
  current_cmdline="$(echo "${current_cmdline}" | sed -E 's#root=PARTUUID=[^ ]+##g')"
  current_cmdline="$(echo "${current_cmdline}" | sed -E 's#[[:space:]]+# #g' | sed -E 's#^ ##; s# $##')"

  cat > "${CMDLINE_FILE}" <<EOF
${current_cmdline} root=PARTUUID=${target_partuuid}
EOF

  sync

  log "Boot target switched to ${target_label}"
  log "cmdline updated: ${CMDLINE_FILE}"
}

print_status() {
  local partuuid_a partuuid_b current

  partuuid_a="$(get_partuuid_by_label rootfs_A || true)"
  partuuid_b="$(get_partuuid_by_label rootfs_B || true)"
  current="$(current_root_partuuid || true)"

  echo "Current cmdline root PARTUUID: ${current}"
  echo "rootfs_A PARTUUID: ${partuuid_a}"
  echo "rootfs_B PARTUUID: ${partuuid_b}"

  if [[ -n "${current}" && "${current}" == "${partuuid_a}" ]]; then
    echo "Current boot slot: rootfs_A"
  elif [[ -n "${current}" && "${current}" == "${partuuid_b}" ]]; then
    echo "Current boot slot: rootfs_B"
  else
    echo "Current boot slot: unknown"
  fi
}

main() {
  require_root
  find_cmdline

  if [[ $# -eq 0 ]]; then
    print_status
    exit 0
  fi

  switch_to_slot "$1"
}

main "$@"
