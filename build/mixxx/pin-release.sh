#!/usr/bin/env bash
# Pin the published Mixxx packages for the image build.
#
# Downloads the arm64 + all .deb assets of the GitHub release for the version in
# mixxx.conf, checks them against the release's SHA256SUMS and writes
# release.sha256 ("<sha256>  <asset name>"). Commit release.sha256: from then on
# build.sh downloads exactly these files and refuses anything else.
#
# Usage: build/mixxx/pin-release.sh
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mixxx.conf
. "${SCRIPT_DIR}/mixxx.conf"

VERSION="${MIXXX_SOURCE_VERSION}${MIXXX_LOCAL_SUFFIX}"
TAG="mixxx/${VERSION//\~/_}"
API="https://api.github.com/repos/${MIXXX_RELEASE_REPO}/releases/tags/${TAG}"
OUT="${SCRIPT_DIR}/release.sha256"

die() { echo "pin-release: $*" >&2; exit 1; }
command -v jq >/dev/null || die "jq is required"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Release ${TAG} of ${MIXXX_RELEASE_REPO}"
curl -fsSL "${API}" -o "${TMP}/release.json" || die "release ${TAG} not found (run the workflow with publish)"

asset_url() { jq -r --arg n "$1" '.assets[] | select(.name == $n) | .browser_download_url' "${TMP}/release.json"; }

sums_url="$(asset_url SHA256SUMS)"
[[ -n "${sums_url}" ]] || die "release has no SHA256SUMS"
curl -fsSL "${sums_url}" -o "${TMP}/SHA256SUMS"

# Runtime packages only (no -dbgsym). GitHub may rename assets, so files are
# matched to SHA256SUMS by content hash, not by name.
mapfile -t names < <(jq -r '.assets[].name | select(endswith(".deb")) | select(test("dbgsym") | not)
                            | select(test("_(arm64|all)\\.deb$"))' "${TMP}/release.json")
(( ${#names[@]} > 0 )) || die "no arm64/all .deb assets in the release"

: > "${TMP}/pinned"
for name in "${names[@]}"; do
  curl -fsSL "$(asset_url "${name}")" -o "${TMP}/${name}"
  sum="$(sha256sum "${TMP}/${name}" | cut -d' ' -f1)"
  grep -q "^${sum} " "${TMP}/SHA256SUMS" || die "${name}: hash ${sum} not listed in the release's SHA256SUMS"
  printf '%s  %s\n' "${sum}" "${name}" >> "${TMP}/pinned"
  echo "  ${name}  ${sum}"
done

{
  echo "# Mixxx ${VERSION}, release ${TAG} of ${MIXXX_RELEASE_REPO}"
  echo "# Written by pin-release.sh on $(date -u +%F); verified against the release SHA256SUMS."
  cat "${TMP}/pinned"
} > "${OUT}"
echo "Wrote ${OUT}"
