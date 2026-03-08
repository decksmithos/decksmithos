#!/usr/bin/env bash
#set -Eeuo pipefail

DECKSMITHOS_PRIMARY_DISPLAY=spi35
DECKSMITHOS_SPI_DTO=waveshare35b-v2
DECKSMITHOS_SPI_FB=/dev/fb0
DECKSMITHOS_SPI_ROTATION=90

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}"
PI_GEN_DIR="${BUILD_DIR}/pi-gen"
PI_GEN_REPO="https://github.com/RPi-Distro/pi-gen.git"
PI_GEN_BRANCH="${PI_GEN_BRANCH:-arm64}"

POSTPROCESS_SCRIPT="${BUILD_DIR}/postprocess-ab.sh"
COMPRESS_OUTPUT="${COMPRESS_OUTPUT:-0}"

DECKSMITHOS_PROFILE="${DECKSMITHOS_PROFILE:-release}"

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_tools() {
  local tools=(git rsync bash sudo find xz)
  local missing=()

  for tool in "${tools[@]}"; do
    command -v "${tool}" >/dev/null 2>&1 || missing+=("${tool}")
  done

  if (( ${#missing[@]} > 0 )); then
    die "Missing required tools: ${missing[*]}"
  fi
}

prepare_pi_gen() {
  if [[ ! -d "${PI_GEN_DIR}/.git" ]]; then
    log "Cloning official pi-gen repository into ${PI_GEN_DIR}"
    git clone --branch "${PI_GEN_BRANCH}" --depth 1 "${PI_GEN_REPO}" "${PI_GEN_DIR}"
    return
  fi

  log "Updating existing pi-gen checkout"
  git -C "${PI_GEN_DIR}" fetch origin "${PI_GEN_BRANCH}" --depth 1
  git -C "${PI_GEN_DIR}" checkout "${PI_GEN_BRANCH}"
  git -C "${PI_GEN_DIR}" reset --hard "origin/${PI_GEN_BRANCH}"

  sudo apt update &&
  sudo apt -y install quilt qemu-user-binfmt zerofree libarchive-tools xxd pigz arch-test
}

generate_password() {
  local password=""
  while [ "${#password}" -lt 24 ]; do
    password="$(
      LC_ALL=C dd if=/dev/urandom bs=256 count=1 2>/dev/null \
        | tr -dc 'A-Za-z0-9@#%^&*()_+=' \
        | cut -c1-24
    )"
  done
  printf '%s' "${password}"
}

sync_decksmithos_files() {
  log "Syncing DecksmithOS build configuration into pi-gen"

  if [ "$DECKSMITHOS_PROFILE" == "dev" ]; then
    rsync -a --delete "${BUILD_DIR}/config-dev" "${PI_GEN_DIR}/config"
  else
    rsync -a --delete "${BUILD_DIR}/config" "${PI_GEN_DIR}/config"
  fi
  FIRST_USER_PASS="$(generate_password)"
  echo "FIRST_USER_PASS=\"${FIRST_USER_PASS}\"" >> "${PI_GEN_DIR}/config"
  rsync -a --delete "${BUILD_DIR}/stage-decksmithos" "${PI_GEN_DIR}/"
  rsync -a --delete "${BUILD_DIR}/stage-decksmithos-dev" "${PI_GEN_DIR}/"
  rsync -a --delete "${BUILD_DIR}/stage-decksmithos-release" "${PI_GEN_DIR}/"
}

run_pi_gen() {
  log "Running pi-gen build"
  cd "${PI_GEN_DIR}"
  # sudo rm -fR ./work/DecksmithOS
  sudo ./build.sh
}

find_latest_pi_gen_image() {
  find "${PI_GEN_DIR}/deploy" -maxdepth 1 -type f -name '*.img' -print -quit
}

run_postprocess() {
  local input_image="$1"

  [[ -x "${POSTPROCESS_SCRIPT}" ]] || chmod +x "${POSTPROCESS_SCRIPT}"

  log "Running A/B post-processing on: ${input_image}"
  sudo "${POSTPROCESS_SCRIPT}" "${input_image}"
}

compress_final_image() {
  local final_image="${BUILD_DIR}/output/decksmithos-ab.img"

  if [[ ! -f "${final_image}" ]]; then
    die "Final image not found: ${final_image}"
  fi

  if [[ "${COMPRESS_OUTPUT}" != "1" ]]; then
    log "Skipping compression (COMPRESS_OUTPUT=${COMPRESS_OUTPUT})"
    return
  fi

  log "Compressing final image with xz"
  sudo xz -T0 -z -f -9 "${final_image}"

  log "Compressed artifact:"
  log "  ${final_image}.xz"
}

main() {
  require_tools
  prepare_pi_gen
  sync_decksmithos_files
  run_pi_gen

  local latest_img
  latest_img="$(find_latest_pi_gen_image)"

  log "Listing deploy directory images"
  find "${PI_GEN_DIR}/deploy" -maxdepth 1 -type f -name *.img | sed 's/^/  /'
  [ "${latest_img}" != "" ] || die "No pi-gen image found in ${PI_GEN_DIR}/deploy"

  log "Latest pi-gen image: ${latest_img}"

  run_postprocess "${latest_img}"
  compress_final_image

  log "Build finished successfully"
  log "pi-gen artifacts: ${PI_GEN_DIR}/deploy"
  log "DecksmithOS final artifacts: ${BUILD_DIR}/output"
}

main "$@"
