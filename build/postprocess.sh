#!/usr/bin/env bash
#set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEPLOY_DIR="${SCRIPT_DIR}/pi-gen/deploy"
WORK_DIR="${SCRIPT_DIR}/work"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MNT_DIR="${WORK_DIR}/mnt"

BOOT_SIZE_MIB="${BOOT_SIZE_MIB:-256}"
ROOTFS_SIZE_MIB="${ROOTFS_SIZE_MIB:-3072}"
SWAP_SIZE_MIB="${SWAP_SIZE_MIB:-1024}"
IMAGE_SIZE_MIB="${IMAGE_SIZE_MIB:-7427}"

mkdir -p "${WORK_DIR}" "${OUTPUT_DIR}" "${MNT_DIR}"

INPUT_IMAGE="${1:-}"
if [[ -z "${INPUT_IMAGE}" ]]; then
  INPUT_IMAGE="$(find "${DEPLOY_DIR}" -maxdepth 1 -type f -name "*.img" | sort | tail -n1 || true)"
fi

if [[ -z "${INPUT_IMAGE}" || ! -f "${INPUT_IMAGE}" ]]; then
  echo "ERROR: no input image found. Pass it explicitly or build pi-gen first." >&2
  exit 1
fi

BASE_LOOP=""
OUT_LOOP=""
cleanup() {
  set +e
  for m in \
    "${MNT_DIR}/src-boot" \
    "${MNT_DIR}/src-root" \
    "${MNT_DIR}/dst-boot" \
    "${MNT_DIR}/dst-rootfs-a" \
    "${MNT_DIR}/dst-rootfs-b"
  do
    mountpoint -q "$m" && umount -R "$m" || true
  done
  [[ -n "${OUT_LOOP}" ]] && losetup -d "${OUT_LOOP}" || true
  [[ -n "${BASE_LOOP}" ]] && losetup -d "${BASE_LOOP}" || true
}
trap cleanup EXIT

SRC_BOOT="${MNT_DIR}/src-boot"
SRC_ROOT="${MNT_DIR}/src-root"
DST_BOOT="${MNT_DIR}/dst-boot"
DST_ROOTFS_A="${MNT_DIR}/dst-rootfs-a"
DST_ROOTFS_B="${MNT_DIR}/dst-rootfs-b"

mkdir -p "$SRC_BOOT" "$SRC_ROOT" "$DST_BOOT" "$DST_ROOTFS_A" "$DST_ROOTFS_B"

OUTPUT_IMAGE="${OUTPUT_DIR}/decksmithos-${DECKSMITHOS_PROFILE}.img"

echo "[1/7] Preparing source image"
BASE_LOOP="$(losetup --find --show --partscan "${INPUT_IMAGE}")"
mount "${BASE_LOOP}p1" "${SRC_BOOT}"
mount "${BASE_LOOP}p2" "${SRC_ROOT}"

echo "[2/7] Creating target A/B image"
truncate -s "${IMAGE_SIZE_MIB}M" "${OUTPUT_IMAGE}"
parted -s "${OUTPUT_IMAGE}" mklabel msdos

#partition 1
boot_start=1
boot_end=$((BOOT_SIZE_MIB))

# partition 2
rootfs_a_start=$((boot_end))
rootfs_a_end=$((rootfs_a_start + ROOTFS_SIZE_MIB))

# partition 3
rootfs_b_start=$((rootfs_a_end))
rootfs_b_end=$((rootfs_b_start + ROOTFS_SIZE_MIB))

# partition 4
EXTENDED_SIZE_MIB=$((SWAP_SIZE_MIB + 2))
extended_start=$((rootfs_b_end))
extended_end=$((extended_start + EXTENDED_SIZE_MIB))

# partition 5
swap_start=$((extended_start + 1))
swap_end=$((swap_start + SWAP_SIZE_MIB))

parted -s "${OUTPUT_IMAGE}" unit MiB mkpart primary fat32 "${boot_start}" "${boot_end}"
parted -s "${OUTPUT_IMAGE}" unit MiB mkpart primary ext4 "${rootfs_a_start}" "${rootfs_a_end}"
parted -s "${OUTPUT_IMAGE}" unit MiB mkpart primary ext4 "${rootfs_b_start}" "${rootfs_b_end}"
parted -s "${OUTPUT_IMAGE}" unit MiB mkpart extended "${extended_start}" "${extended_end}"
parted -s "${OUTPUT_IMAGE}" unit MiB mkpart logical linux-swap "${swap_start}" "${swap_end}"
parted -s "${OUTPUT_IMAGE}" set 1 boot on

OUT_LOOP="$(losetup --find --show --partscan "${OUTPUT_IMAGE}")"

echo "[3/7] Formatting target partitions"
mkfs.vfat -F 32 -n BOOT "${OUT_LOOP}p1"
mkfs.ext4 -F -L rootfs_A "${OUT_LOOP}p2"
mkfs.ext4 -F -L rootfs_B "${OUT_LOOP}p3"
mkswap -L swap "${OUT_LOOP}p5"

echo "[4/7] Mounting target partitions"
mount "${OUT_LOOP}p1" "${DST_BOOT}"
mount "${OUT_LOOP}p2" "${DST_ROOTFS_A}"
mount "${OUT_LOOP}p3" "${DST_ROOTFS_B}"

echo "[5/7] Copying boot and rootfs"
rsync -aHAX --delete "${SRC_BOOT}/" "${DST_BOOT}/"
rsync -aHAX --delete "${SRC_ROOT}/" "${DST_ROOTFS_A}/"
rsync -aHAX --delete "${SRC_ROOT}/" "${DST_ROOTFS_B}/"

echo "[7/7] Writing fstab and cmdline"
BOOT_UUID="$(blkid -s UUID -o value "${OUT_LOOP}p1")"
ROOTFS_A_UUID="$(blkid -s UUID -o value "${OUT_LOOP}p2")"
ROOTFS_B_UUID="$(blkid -s UUID -o value "${OUT_LOOP}p3")"
ROOTFS_A_PARTUUID="$(blkid -s PARTUUID -o value "${OUT_LOOP}p2")"

cat > "${DST_ROOTFS_A}/etc/fstab" <<EOF
UUID=${ROOTFS_A_UUID}   /               ext4    defaults,noatime                    0 1
UUID=${BOOT_UUID}       /boot/firmware  vfat    defaults,noatime                    0 2
LABEL=storage           /storage        ext4    defaults,noatime,nofail             0 2
LABEL=swap              none            swap    sw                                  0 0
tmpfs                   /tmp            tmpfs   nosuid,nodev,mode=1777,size=256M    0 0
tmpfs                   /var/tmp        tmpfs   nosuid,nodev,mode=1777,size=128M    0 0
/storage/logs           /var/log        bind    bind,nofail  0 0
EOF

cat > "${DST_ROOTFS_B}/etc/fstab" <<EOF
UUID=${ROOTFS_B_UUID}   /               ext4    defaults,noatime                    0 1
UUID=${BOOT_UUID}       /boot/firmware  vfat    defaults,noatime                    0 2
LABEL=storage           /storage        ext4    defaults,noatime,nofail             0 2
LABEL=swap              none            swap    sw                                  0 0
tmpfs                   /tmp            tmpfs   nosuid,nodev,mode=1777,size=256M    0 0
tmpfs                   /var/tmp        tmpfs   nosuid,nodev,mode=1777,size=128M    0 0
/storage/logs           /var/log        bind    bind,nofail                         0 0
EOF

CMDLINE_FILE=""
if [[ -f "${DST_BOOT}/cmdline.txt" ]]; then
  CMDLINE_FILE="${DST_BOOT}/cmdline.txt"
elif [[ -f "${DST_BOOT}/firmware/cmdline.txt" ]]; then
  CMDLINE_FILE="${DST_BOOT}/firmware/cmdline.txt"
fi

if [[ -z "${CMDLINE_FILE}" ]]; then
  echo "ERROR: cmdline.txt not found in target boot partition" >&2
  exit 1
fi

CURRENT_CMDLINE="$(tr -d '\n' < "${CMDLINE_FILE}")"
CURRENT_CMDLINE="$(echo "${CURRENT_CMDLINE}" | sed -E 's#root=[^ ]+##g')"
CURRENT_CMDLINE="$(echo "${CURRENT_CMDLINE}" | sed -E 's#rootfstype=[^ ]+##g')"
CURRENT_CMDLINE="$(echo "${CURRENT_CMDLINE}" | sed -E 's#[[:space:]]+# #g' | sed -E 's#^ ##; s# $##')"

if [ "${DECKSMITHOS_PROFILE}" == "dev" ]; then
  QUIET=""
else
  QUIET="quiet splash vt.global_cursor_default=0"
fi

if [ "${DECKSMITHOS_PRIMARY_DISPLAY}" == "spi35" ]; then
  FB="fbcon=map:10 fbcon=font:ProFont6x11"
else
  FB=""
fi

cat > "${CMDLINE_FILE}" <<EOF
${CURRENT_CMDLINE} root=PARTUUID=${ROOTFS_A_PARTUUID} rootfstype=ext4 rootwait panic=1 ${QUIET} ${FB} plymouth.ignore-serial-consoles usbcore.autosuspend=-1
EOF

echo "[8/8] Done"
sync

echo
echo "Created:"
echo "  ${OUTPUT_IMAGE}"
echo
echo "Initial boot slot:"
echo "  rootfs_A"
