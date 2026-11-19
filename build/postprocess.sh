#!/usr/bin/env bash
# Turn the pi-gen image (bootfs + rootfs) into the DecksmithOS A/B disk image.
#
# GPT layout (partition 7 "storage" is created on first boot):
#   p1 autoboot  FAT16  PARTLABEL=autoboot   autoboot.txt only (bootloader slot selection)
#   p2 boot_A    FAT32  PARTLABEL=boot_A     firmware, kernel, config.txt, cmdline.txt of slot A
#   p3 boot_B    FAT32  PARTLABEL=boot_B     same for slot B
#   p4 rootfs_A  ext4   PARTLABEL=rootfs_A
#   p5 rootfs_B  ext4   PARTLABEL=rootfs_B
#   p6 swap      swap   PARTLABEL=swap
#   p7 storage   ext4   PARTLABEL=storage    (first boot, see decksmithos-init-storage)
#
# Slot selection uses the Raspberry Pi bootloader's tryboot A/B mode
# (autoboot.txt, tryboot_a_b=1): boot_A + rootfs_A form slot A, boot_B +
# rootfs_B slot B. Each slot has its own kernel and boot configuration, so a
# slot is updated as a whole. See decksmithos-slot and docs/disk-layout.md.
# Both slots receive the same system initially.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEPLOY_DIR="${SCRIPT_DIR}/pi-gen/deploy"
WORK_DIR="${SCRIPT_DIR}/work"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MNT_DIR="${WORK_DIR}/mnt"

AUTOBOOT_SIZE_MIB="${AUTOBOOT_SIZE_MIB:-32}"
BOOT_SIZE_MIB="${BOOT_SIZE_MIB:-512}"
ROOTFS_SIZE_MIB="${ROOTFS_SIZE_MIB:-3072}"
SWAP_SIZE_MIB="${SWAP_SIZE_MIB:-1024}"
PART_START_MIB=1
# Last partition end + 1 MiB for the backup GPT header/table at the end of the image.
IMAGE_SIZE_MIB=$(( PART_START_MIB + AUTOBOOT_SIZE_MIB + 2 * BOOT_SIZE_MIB + 2 * ROOTFS_SIZE_MIB + SWAP_SIZE_MIB + 1 ))

PROFILE="${DECKSMITHOS_PROFILE:-release}"
DISPLAY_PROFILE="${DECKSMITHOS_PRIMARY_DISPLAY:-}"

die() { echo "ERROR: $*" >&2; exit 1; }

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}" "${MNT_DIR}"

INPUT_IMAGE="${1:-}"
if [[ -z "${INPUT_IMAGE}" ]]; then
  INPUT_IMAGE="$(find "${DEPLOY_DIR}" -maxdepth 1 -type f -name "*.img" | sort | tail -n1 || true)"
fi
[[ -n "${INPUT_IMAGE}" && -f "${INPUT_IMAGE}" ]] \
  || die "no input image found. Pass it explicitly or build pi-gen first."

# Kernel console settings come from the display profile (single source of truth).
DISPLAY_CMDLINE_FILE="${SCRIPT_DIR}/stage-decksmithos/03-display-profile/files/${DISPLAY_PROFILE}/cmdline.txt"
[[ -n "${DISPLAY_PROFILE}" && -f "${DISPLAY_CMDLINE_FILE}" ]] \
  || die "display profile cmdline not found: ${DISPLAY_CMDLINE_FILE} (DECKSMITHOS_PRIMARY_DISPLAY='${DISPLAY_PROFILE}')"

SRC_BOOT="${MNT_DIR}/src-boot"
SRC_ROOT="${MNT_DIR}/src-root"
DST_AUTOBOOT="${MNT_DIR}/dst-autoboot"
DST_BOOT_A="${MNT_DIR}/dst-boot-a"
DST_BOOT_B="${MNT_DIR}/dst-boot-b"
DST_ROOTFS_A="${MNT_DIR}/dst-rootfs-a"
DST_ROOTFS_B="${MNT_DIR}/dst-rootfs-b"
MOUNTS=("${SRC_BOOT}" "${SRC_ROOT}" "${DST_AUTOBOOT}" "${DST_BOOT_A}" "${DST_BOOT_B}" "${DST_ROOTFS_A}" "${DST_ROOTFS_B}")

BASE_LOOP=""
OUT_LOOP=""
cleanup() {
  set +e
  for m in "${MOUNTS[@]}"; do
    mountpoint -q "$m" && umount -R "$m"
  done
  [[ -n "${OUT_LOOP}" ]] && losetup -d "${OUT_LOOP}"
  [[ -n "${BASE_LOOP}" ]] && losetup -d "${BASE_LOOP}"
}
trap cleanup EXIT

mkdir -p "${MOUNTS[@]}"

OUTPUT_IMAGE="${OUTPUT_DIR}/decksmithos-${PROFILE}.img"

echo "[1/6] Preparing source image ${INPUT_IMAGE}"
BASE_LOOP="$(losetup --find --show --partscan --read-only "${INPUT_IMAGE}")"
mount -o ro "${BASE_LOOP}p1" "${SRC_BOOT}"
mount -o ro "${BASE_LOOP}p2" "${SRC_ROOT}"

echo "[2/6] Creating GPT image (${IMAGE_SIZE_MIB} MiB)"
rm -f "${OUTPUT_IMAGE}"
truncate -s "${IMAGE_SIZE_MIB}M" "${OUTPUT_IMAGE}"
parted -s "${OUTPUT_IMAGE}" mklabel gpt

# With GPT the first mkpart argument is the PARTLABEL. FAT partitions get the
# "Microsoft basic data" type GUID; no boot/esp flag is needed.
start=${PART_START_MIB}
mkpart() { # <label> <fs-type> <size MiB>
  parted -s "${OUTPUT_IMAGE}" unit MiB mkpart "$1" "$2" "${start}" "$((start + $3))"
  start=$((start + $3))
}
mkpart autoboot fat16      "${AUTOBOOT_SIZE_MIB}"
mkpart boot_A   fat32      "${BOOT_SIZE_MIB}"
mkpart boot_B   fat32      "${BOOT_SIZE_MIB}"
mkpart rootfs_A ext4       "${ROOTFS_SIZE_MIB}"
mkpart rootfs_B ext4       "${ROOTFS_SIZE_MIB}"
mkpart swap     linux-swap "${SWAP_SIZE_MIB}"

OUT_LOOP="$(losetup --find --show --partscan "${OUTPUT_IMAGE}")"

echo "[3/6] Formatting partitions"
mkfs.vfat -F 16 -n AUTOBOOT "${OUT_LOOP}p1"
mkfs.vfat -F 32 -n BOOT_A "${OUT_LOOP}p2"
mkfs.vfat -F 32 -n BOOT_B "${OUT_LOOP}p3"
mkfs.ext4 -F -L rootfs_A "${OUT_LOOP}p4"
mkfs.ext4 -F -L rootfs_B "${OUT_LOOP}p5"
mkswap -L swap "${OUT_LOOP}p6"

mount "${OUT_LOOP}p1" "${DST_AUTOBOOT}"
mount "${OUT_LOOP}p2" "${DST_BOOT_A}"
mount "${OUT_LOOP}p3" "${DST_BOOT_B}"
mount "${OUT_LOOP}p4" "${DST_ROOTFS_A}"
mount "${OUT_LOOP}p5" "${DST_ROOTFS_B}"

echo "[4/6] Copying boot and root filesystems into both slots"
# FAT cannot store owners/ACLs/xattrs: copy the boot partitions with -rt only.
rsync -rt --delete "${SRC_BOOT}/" "${DST_BOOT_A}/"
rsync -rt --delete "${SRC_BOOT}/" "${DST_BOOT_B}/"
rsync -aHAX --delete "${SRC_ROOT}/" "${DST_ROOTFS_A}/"

# Release: remove package management. This cannot happen in the pi-gen stage,
# because pi-gen's export-image still runs apt-get after the last stage.
if [[ "${PROFILE}" == "release" ]]; then
  echo "  removing package management from the release rootfs"
  mount --bind /dev "${DST_ROOTFS_A}/dev"
  mount -t proc proc "${DST_ROOTFS_A}/proc"
  # shellcheck disable=SC2016 # expanded inside the chroot
  chroot "${DST_ROOTFS_A}" /bin/sh -ec '
    pkgs="$(dpkg-query -W -f="\${db:Status-Abbrev} \${Package}\n" apt apt-utils apt-listchanges 2>/dev/null | awk "\$1 == \"ii\" {print \$2}")"
    echo "  purging: ${pkgs}"
    [ -z "${pkgs}" ] || dpkg --purge --force-remove-essential --force-depends ${pkgs}
    dpkg -l > /var/lib/dpkg/decksmithos-packages.txt'
  umount "${DST_ROOTFS_A}/proc" "${DST_ROOTFS_A}/dev"
  rm -rf "${DST_ROOTFS_A}/var/lib/apt" "${DST_ROOTFS_A}/var/cache/apt" \
         "${DST_ROOTFS_A}/var/log/apt" "${DST_ROOTFS_A}/etc/apt"
  [[ ! -e "${DST_ROOTFS_A}/usr/bin/apt-get" ]] || die "apt-get still present in the release rootfs"
fi

# Slot B starts as an exact copy of slot A.
rsync -aHAX --delete "${DST_ROOTFS_A}/" "${DST_ROOTFS_B}/"

echo "[5/6] Writing per-slot fstab and cmdline.txt"
[[ -f "${SRC_BOOT}/cmdline.txt" ]] || die "cmdline.txt not found in the source boot partition"
# Drop what this script sets itself, and Raspberry Pi OS first-boot actions:
# "resize" would grow the root partition, which is not the last one here.
BASE_CMDLINE="$(tr -s ' \n' '\n\n' < "${SRC_BOOT}/cmdline.txt" \
  | grep -vE '^(root=|rootfstype=|rootwait$|panic=|quiet$|splash$|resize$|init=.*firstboot|systemd\.run.*firstboot|$)' \
  | paste -sd' ')"

if [[ "${PROFILE}" == "dev" ]]; then
  QUIET=""
else
  QUIET="quiet splash vt.global_cursor_default=0"
fi
FB="$(tr -d '\n' < "${DISPLAY_CMDLINE_FILE}")"

partuuid() { blkid -p -o value -s PART_ENTRY_UUID "$1"; }

write_slot() { # <slot> <boot dev> <boot mount> <root dev> <root mount>
  local slot="$1" boot_dev="$2" boot_mnt="$3" root_dev="$4" root_mnt="$5"
  local boot_partuuid root_partuuid
  boot_partuuid="$(partuuid "${boot_dev}")"
  root_partuuid="$(partuuid "${root_dev}")"
  [[ -n "${boot_partuuid}" && -n "${root_partuuid}" ]] || die "could not read PARTUUIDs for slot ${slot}"

  # PARTUUIDs (not PARTLABELs) so that a USB disk with the same labels cannot be picked.
  cat > "${root_mnt}/etc/fstab" <<EOF
# DecksmithOS slot ${slot}
PARTUUID=${root_partuuid}  /               ext4   defaults,noatime                    0 1
PARTUUID=${boot_partuuid}  /boot/firmware  vfat   defaults,noatime                    0 2
LABEL=storage              /storage        ext4   defaults,noatime,nofail             0 2
PARTLABEL=swap             none            swap   sw,nofail                           0 0
tmpfs                      /tmp            tmpfs  nosuid,nodev,mode=1777,size=256M    0 0
tmpfs                      /var/tmp        tmpfs  nosuid,nodev,mode=1777,size=128M    0 0
/storage/logs              /var/log        none   bind,nofail                         0 0
EOF

  echo "${BASE_CMDLINE} root=PARTUUID=${root_partuuid} rootfstype=ext4 rootwait panic=1 ${QUIET} ${FB} plymouth.ignore-serial-consoles usbcore.autosuspend=-1" \
    | sed -E 's#[[:space:]]+# #g' > "${boot_mnt}/cmdline.txt"

  echo "  slot ${slot}: boot PARTUUID=${boot_partuuid}, root PARTUUID=${root_partuuid}"
}
write_slot A "${OUT_LOOP}p2" "${DST_BOOT_A}" "${OUT_LOOP}p4" "${DST_ROOTFS_A}"
write_slot B "${OUT_LOOP}p3" "${DST_BOOT_B}" "${OUT_LOOP}p5" "${DST_ROOTFS_B}"

echo "[6/6] Writing autoboot.txt (default slot A, tryboot slot B)"
# Same format as decksmithos-slot writes on the device.
cat > "${DST_AUTOBOOT}/autoboot.txt" <<'EOF'
[all]
tryboot_a_b=1
boot_partition=2
[tryboot]
boot_partition=3
EOF

sync
echo
echo "Created: ${OUTPUT_IMAGE}"
echo "Default boot slot: A (p2 boot_A + p4 rootfs_A)"
