#!/usr/bin/env bash
# Rebuild the pinned Debian Mixxx source package (see mixxx.conf) for the
# DecksmithOS base release.
#
# Runs as root inside a Debian trixie arm64 environment: the CI container
# (.github/workflows/mixxx-deb.yml) or, as a fallback, a CM5 dev image.
#
# Usage: build-mixxx-deb.sh [--prepare-only] <output-dir>
#   --prepare-only  fetch/verify the source, bump the version and install
#                   build dependencies, but do not compile (quick self-test).
#
# Environment:
#   MIXXX_NOCHECK=1     skip the upstream test suite (DEB_BUILD_OPTIONS=nocheck)
#   CCACHE_DIR          enable ccache with this cache directory
#   ALLOW_ANY_ARCH=1    allow running on a non-arm64 host (testing only)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mixxx.conf
. "${SCRIPT_DIR}/mixxx.conf"

PREPARE_ONLY=0
if [[ "${1:-}" == "--prepare-only" ]]; then
  PREPARE_ONLY=1
  shift
fi
OUT_DIR="${1:?usage: $0 [--prepare-only] <output-dir>}"
mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"

LOCAL_VERSION="${MIXXX_SOURCE_VERSION}${MIXXX_LOCAL_SUFFIX}"
DSC="mixxx_${MIXXX_SOURCE_VERSION}.dsc"
POOL_URL="https://deb.debian.org/debian/pool/main/m/mixxx/${DSC}"
SNAPSHOT_URL="https://snapshot.debian.org/archive/debian/${MIXXX_SNAPSHOT_TIMESTAMP}/pool/main/m/mixxx/${DSC}"

log() { printf '\n[build-mixxx-deb] %s\n' "$*"; }
die() { printf '[build-mixxx-deb] ERROR: %s\n' "$*" >&2; exit 1; }

# --- Environment checks ------------------------------------------------------------
[[ "${EUID}" -eq 0 ]] || die "run as root (inside the build container or with sudo)"
. /etc/os-release
[[ "${VERSION_CODENAME:-}" == "${MIXXX_TARGET_SUITE}" ]] \
  || die "this is '${VERSION_CODENAME:-unknown}', expected Debian ${MIXXX_TARGET_SUITE}"
ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" != "arm64" && "${ALLOW_ANY_ARCH:-0}" != "1" ]]; then
  die "architecture is ${ARCH}, expected arm64 (set ALLOW_ANY_ARCH=1 for testing)"
fi

log "Mixxx ${MIXXX_SOURCE_VERSION} -> ${LOCAL_VERSION} for ${MIXXX_TARGET_SUITE}/${ARCH}"

# --- Tools ----------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates ccache devscripts dpkg-dev fakeroot \
  debian-keyring gpgv wget

# --- Fetch and verify the source -------------------------------------------------------
WORK="$(mktemp -d /tmp/mixxx-build.XXXXXX)"
cd "${WORK}"

# dget verifies the .dsc signature against debian-keyring (dscverify) and the
# checksums of every file listed in the .dsc.
log "Fetching ${DSC}"
if ! dget -x "${POOL_URL}"; then
  log "Not in the pool anymore, falling back to snapshot.debian.org"
  rm -f ./*.dsc ./*.tar.*
  dget -x "${SNAPSHOT_URL}"
fi

SRC_DIR="$(find . -maxdepth 1 -mindepth 1 -type d -name 'mixxx-*' | head -n1)"
[[ -n "${SRC_DIR}" ]] || die "source directory not found after extraction"
cd "${SRC_DIR}"

# --- Mark as a DecksmithOS rebuild -----------------------------------------------------
# The "~" suffix deliberately sorts below the Debian version, hence --force-bad-version.
DEBFULLNAME="DecksmithOS Build" DEBEMAIL="build@decksmithos.invalid" \
  dch --newversion "${LOCAL_VERSION}" --distribution "${MIXXX_TARGET_SUITE}" \
      --force-distribution --force-bad-version \
      "Rebuild of Debian ${MIXXX_SOURCE_VERSION} for ${MIXXX_TARGET_SUITE} (DecksmithOS)."

# --- DecksmithOS patches ---------------------------------------------------------------
# build/mixxx/patches/*.patch are appended to the Debian quilt series and applied
# now, so that a patch which no longer applies fails here (also in --prepare-only).
shopt -s nullglob
PATCHES=("${SCRIPT_DIR}"/patches/*.patch)
shopt -u nullglob
if (( ${#PATCHES[@]} > 0 )); then
  mkdir -p debian/patches
  touch debian/patches/series
  for patch in "${PATCHES[@]}"; do
    name="decksmithos-$(basename "${patch}")"
    cp "${patch}" "debian/patches/${name}"
    echo "${name}" >> debian/patches/series
    DEBFULLNAME="DecksmithOS Build" DEBEMAIL="build@decksmithos.invalid" \
      dch --append "Add debian/patches/${name}."
  done
  log "Applying patches: ${PATCHES[*]##*/}"
  dpkg-source --before-build .
fi

# --- Build dependencies ----------------------------------------------------------------
if [[ -n "${MIXXX_BACKPORTED_BUILD_TOOLS:-}" ]]; then
  log "Installing build tools from ${MIXXX_TARGET_SUITE}-backports: ${MIXXX_BACKPORTED_BUILD_TOOLS}"
  cat > /etc/apt/sources.list.d/backports.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: ${MIXXX_TARGET_SUITE}-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
  apt-get update
  # shellcheck disable=SC2086
  apt-get install -y --no-install-recommends -t "${MIXXX_TARGET_SUITE}-backports" ${MIXXX_BACKPORTED_BUILD_TOOLS}
fi

log "Installing build dependencies"
apt-get build-dep -y --no-install-recommends ./

if [[ "${PREPARE_ONLY}" == "1" ]]; then
  log "Prepare-only run finished (source verified, build dependencies installed)"
  dpkg-parsechangelog -S Version | tee "${OUT_DIR}/prepared-version.txt"
  exit 0
fi

# --- Build ----------------------------------------------------------------------------
if [[ -n "${CCACHE_DIR:-}" ]]; then
  mkdir -p "${CCACHE_DIR}"
  ccache --max-size=2G
  ccache --zero-stats
  # CMake >= 3.17 reads these as defaults for the compiler launcher.
  export CMAKE_C_COMPILER_LAUNCHER=ccache CMAKE_CXX_COMPILER_LAUNCHER=ccache
fi

BUILD_OPTS="parallel=$(nproc)"
[[ "${MIXXX_NOCHECK:-0}" == "1" ]] && BUILD_OPTS+=" nocheck"
export DEB_BUILD_OPTIONS="${BUILD_OPTS}"
log "dpkg-buildpackage (DEB_BUILD_OPTIONS=${DEB_BUILD_OPTIONS})"
dpkg-buildpackage -b -us -uc

[[ -n "${CCACHE_DIR:-}" ]] && ccache --show-stats

# --- Collect results ------------------------------------------------------------------
cd "${WORK}"
cp -v ./*.deb ./*.buildinfo ./*.changes "${OUT_DIR}/"
{
  echo "source_version=${MIXXX_SOURCE_VERSION}"
  echo "package_version=${LOCAL_VERSION}"
  echo "suite=${MIXXX_TARGET_SUITE}"
  echo "arch=${ARCH}"
  echo "deb_build_options=${DEB_BUILD_OPTIONS}"
  echo "debhelper=$(dpkg-query -W -f '${Version}' debhelper)"
  echo "built_at=$(date -u +%FT%TZ)"
} > "${OUT_DIR}/build-info.txt"
(cd "${OUT_DIR}" && sha256sum ./*.deb ./*.buildinfo ./*.changes build-info.txt > SHA256SUMS)

log "Done. Artifacts in ${OUT_DIR}:"
ls -l "${OUT_DIR}"
