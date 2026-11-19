#!/usr/bin/env bash
#set -Eeuo pipefail

# Display profile: a directory name under stage-decksmithos/03-display-profile/files/
#   td2   - Raspberry Pi Touch Display 2 (7" DSI), verified on CM5
#   spi35 - Waveshare 3.5" SPI, unverified on CM5
export DECKSMITHOS_PRIMARY_DISPLAY="${DECKSMITHOS_PRIMARY_DISPLAY:-td2}"
export DECKSMITHOS_SPI_DTO="${DECKSMITHOS_SPI_DTO:-waveshare35a}"
export DECKSMITHOS_SPI_FB="${DECKSMITHOS_SPI_FB:-/dev/fb1}"
export DECKSMITHOS_SPI_ROTATION="${DECKSMITHOS_SPI_ROTATION:-0}"

# Mixxx package source (see mixxx/README.md):
#   release     - the GitHub release pinned in mixxx/release.sha256 (default)
#   dir:<path>  - local .debs, e.g. a downloaded CI artifact (checked against its SHA256SUMS)
#   debian      - the base release's own mixxx package (trixie: 2.5.0); testing only
export DECKSMITHOS_MIXXX="${DECKSMITHOS_MIXXX:-release}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}"
PI_GEN_DIR="${BUILD_DIR}/pi-gen"
PI_GEN_REPO="https://github.com/RPi-Distro/pi-gen.git"
PI_GEN_BRANCH="${PI_GEN_BRANCH:-arm64}"

POSTPROCESS_SCRIPT="${BUILD_DIR}/postprocess.sh"
BUILD_STARTED=""
COMPRESS_OUTPUT="${COMPRESS_OUTPUT:-0}"

export DECKSMITHOS_PROFILE="${DECKSMITHOS_PROFILE:-release}"

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

# Local fixes to the pi-gen checkout (re-applied after every reset).
patch_pi_gen() {
  # ensure_loopdev_partitions: udev may create /dev/loopNpM between the
  # "[ ! -b ]" test and mknod, which then fails with "File exists".
  sed -i 's|^\t\t\tmknod "/dev/\$partition" b "\${majmin%:\*}" "\${majmin#\*:}"$|&  \|\| [ -b "/dev/$partition" ]|' \
    "${PI_GEN_DIR}/scripts/common"
  grep -q 'mknod "/dev/$partition".*|| \[ -b' "${PI_GEN_DIR}/scripts/common" \
    || die "could not patch ensure_loopdev_partitions in pi-gen/scripts/common"
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

# Put the pinned Mixxx .debs into the stage (00-install-packages/01-run.sh installs them).
fetch_mixxx_debs() {
  local dest="$1" conf="${BUILD_DIR}/mixxx/mixxx.conf" pins="${BUILD_DIR}/mixxx/release.sha256"
  rm -rf "${dest}"
  mkdir -p "${dest}"

  case "${DECKSMITHOS_MIXXX}" in
    debian)
      log "WARNING: using the base release's mixxx package (testing only, no DecksmithOS patches)"
      ;;
    dir:*)
      local src="${DECKSMITHOS_MIXXX#dir:}"
      [[ -f "${src}/SHA256SUMS" ]] || die "${src}/SHA256SUMS missing"
      (cd "${src}" && sha256sum --quiet -c --ignore-missing SHA256SUMS) || die "checksum mismatch in ${src}"
      find "${src}" -maxdepth 1 -name '*.deb' ! -name '*dbgsym*' \( -name '*_arm64.deb' -o -name '*_all.deb' \) \
        -exec cp -v {} "${dest}/" \;
      ;;
    release)
      [[ -f "${pins}" ]] || die "${pins} missing: publish the Mixxx release and run mixxx/pin-release.sh (or set DECKSMITHOS_MIXXX)"
      command -v jq >/dev/null || die "jq is required to download the Mixxx release"
      local repo version tag json name url
      # shellcheck source=mixxx/mixxx.conf
      repo="$(. "${conf}" && echo "${MIXXX_RELEASE_REPO}")"
      # shellcheck source=mixxx/mixxx.conf
      version="$(. "${conf}" && echo "${MIXXX_SOURCE_VERSION}${MIXXX_LOCAL_SUFFIX}")"
      tag="mixxx/${version//\~/_}"
      grep -q "^# Mixxx ${version}," "${pins}" || die "${pins} does not pin Mixxx ${version}; re-run mixxx/pin-release.sh"
      log "Downloading Mixxx ${version} from release ${tag} of ${repo}"
      json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}")" || die "release ${tag} not found"
      while read -r _ name; do
        url="$(jq -r --arg n "${name}" '.assets[] | select(.name == $n) | .browser_download_url' <<< "${json}")"
        [[ -n "${url}" ]] || die "asset ${name} not in release ${tag}"
        curl -fsSL "${url}" -o "${dest}/${name}" || die "download of ${name} failed"
      done < <(grep -v '^#' "${pins}")
      (cd "${dest}" && grep -v '^#' "${pins}" | sha256sum --quiet -c -) || die "Mixxx package checksum mismatch"
      ;;
    *)
      die "unknown DECKSMITHOS_MIXXX='${DECKSMITHOS_MIXXX}' (release | dir:<path> | debian)"
      ;;
  esac
}

sync_decksmithos_files() {
  log "Syncing DecksmithOS build configuration into pi-gen"

  if [ "$DECKSMITHOS_PROFILE" == "dev" ]; then
    rsync -a --delete "${BUILD_DIR}/config-dev" "${PI_GEN_DIR}/config"
  else
    rsync -a --delete "${BUILD_DIR}/config" "${PI_GEN_DIR}/config"
  fi

  # Rebuild every stage from scratch unless CLEAN=0 (reuses pi-gen/work).
  echo "CLEAN=${CLEAN:-1}" >> "${PI_GEN_DIR}/config"
  FIRST_USER_PASS="$(generate_password)"
  echo "FIRST_USER_PASS=\"${FIRST_USER_PASS}\"" >> "${PI_GEN_DIR}/config"
  echo >> "${PI_GEN_DIR}/config"
  echo "export DECKSMITHOS_PRIMARY_DISPLAY=\"${DECKSMITHOS_PRIMARY_DISPLAY}\"" >> "${PI_GEN_DIR}/config"
  echo "export DECKSMITHOS_SPI_DTO=\"${DECKSMITHOS_SPI_DTO}\"" >> "${PI_GEN_DIR}/config"
  echo "export DECKSMITHOS_SPI_FB=\"${DECKSMITHOS_SPI_FB}\"" >> "${PI_GEN_DIR}/config"
  echo "export DECKSMITHOS_SPI_ROTATION=\"${DECKSMITHOS_SPI_ROTATION}\"" >> "${PI_GEN_DIR}/config"
  echo "export DECKSMITHOS_MIXXX=\"${DECKSMITHOS_MIXXX%%:*}\"" >> "${PI_GEN_DIR}/config"


  rsync -a --delete "${BUILD_DIR}/stage-decksmithos" "${PI_GEN_DIR}/"
  # Mixxx skins live in the repository root (mixxx/skins); stage 02 installs them.
  rsync -a --delete "${BUILD_DIR}/../mixxx/skins/" \
    "${PI_GEN_DIR}/stage-decksmithos/02-install-session-files/files/skins/"
  fetch_mixxx_debs "${PI_GEN_DIR}/stage-decksmithos/00-install-packages/files/mixxx"
  rsync -a --delete "${BUILD_DIR}/stage-decksmithos-dev" "${PI_GEN_DIR}/"
  rsync -a --delete "${BUILD_DIR}/stage-decksmithos-release" "${PI_GEN_DIR}/"

  rm -f "${PI_GEN_DIR}/stage2/EXPORT_IMAGE"
}

run_pi_gen() {
  log "Running pi-gen build"
  cd "${PI_GEN_DIR}" || die "cannot enter ${PI_GEN_DIR}"
  # sudo rm -fR ./work/DecksmithOS
  BUILD_STARTED="$(mktemp -t decksmithos-pi-gen-start.XXXXXX)"
  sudo ./build.sh || die "pi-gen build failed (see the log above)"
}

find_latest_pi_gen_image() {
  # Newest image: deploy/ keeps the images of earlier builds.
  # Only an image written by this run: a failed run must not post-process an old one.
  find "${PI_GEN_DIR}/deploy" -maxdepth 1 -type f -name '*.img' -newer "${BUILD_STARTED}" -printf '%T@ %p\n' \
    | sort -n | tail -n1 | cut -d' ' -f2-
}

run_postprocess() {
  local input_image="$1"

  [ -x "${POSTPROCESS_SCRIPT}" ] || chmod +x "${POSTPROCESS_SCRIPT}"

  log "Running A/B post-processing on: ${input_image}"
  sudo DECKSMITHOS_PROFILE="${DECKSMITHOS_PROFILE}" \
    DECKSMITHOS_PRIMARY_DISPLAY="${DECKSMITHOS_PRIMARY_DISPLAY}" \
    "${POSTPROCESS_SCRIPT}" "${input_image}"
}

compress_final_image() {
  local final_image="${BUILD_DIR}/output/decksmithos-${DECKSMITHOS_PROFILE}.img"

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
  patch_pi_gen
  sync_decksmithos_files
  run_pi_gen

  local latest_img
  latest_img="$(find_latest_pi_gen_image)"

  log "Listing deploy directory images"
  find "${PI_GEN_DIR}/deploy" -maxdepth 1 -type f -name "*.img" | sed 's/^/  /'
  [ "${latest_img}" != "" ] || die "No pi-gen image found in ${PI_GEN_DIR}/deploy"

  log "Latest pi-gen image: ${latest_img}"

  run_postprocess "${latest_img}"
  compress_final_image

  log "Build finished successfully"
  log "pi-gen artifacts: ${PI_GEN_DIR}/deploy"
  log "DecksmithOS final artifacts: ${BUILD_DIR}/output"
}

main "$@"
