#!/bin/bash
# Download the demo tracks listed in tracks.tsv (pinned by SHA256) and lay them
# out as a music library tree:
#
#   fetch.sh <dest>   ->  <dest>/<Genre>/<Artist> - <Title>.<ext>
#                         <dest>/CREDITS.txt
#
# Downloads are cached in build/demo-music/cache/ (not in git). A track whose
# download fails or whose SHA256 differs stops the build: the image must contain
# exactly the files whose licenses were checked.
#
# The tree is installed into slot A of the full disk image only
# (/usr/share/decksmithos/demo-library, stage 05-demo-music) and copied to
# /storage/library/Demo when /storage is created on first boot. Update files
# leave it out (make-update.sh), so an update never adds or restores it.
set -Eeuo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LIST="${HERE}/tracks.tsv"
CACHE="${HERE}/cache"
DEST="${1:?usage: fetch.sh <dest>}"

mkdir -p "${CACHE}"
rm -rf "${DEST}"
mkdir -p "${DEST}"

credits="${DEST}/CREDITS.txt"
cat > "${credits}" <<'HDR'
DecksmithOS demo tracks
=======================

These tracks are included so that a new DecksmithOS device can be tried
without bringing music. Each is distributed under the license named below,
by its author, from the source given. They are not part of DecksmithOS and
are not covered by its license. Delete them at any time; DecksmithOS never
puts them back (only flashing a full disk image does).

HDR

n=0
while IFS=$'\t' read -r genre artist title license license_url source_url download_url sha256 ext; do
  [[ -z "${genre}" || "${genre}" == \#* || "${genre}" == genre ]] && continue
  cached="${CACHE}/${sha256}.${ext}"
  if [[ ! -f "${cached}" ]] || [[ "$(sha256sum "${cached}" | cut -d' ' -f1)" != "${sha256}" ]]; then
    echo "demo-music: downloading ${artist} - ${title}"
    curl -fsSL --retry 3 -o "${cached}.part" "${download_url}"
    got="$(sha256sum "${cached}.part" | cut -d' ' -f1)"
    if [[ "${got}" != "${sha256}" ]]; then
      rm -f "${cached}.part"
      echo "demo-music: SHA256 mismatch for ${download_url}: got ${got}, expected ${sha256}" >&2
      exit 1
    fi
    mv "${cached}.part" "${cached}"
  fi
  name="${artist} - ${title}.${ext}"
  name="${name//\//-}"
  mkdir -p "${DEST}/${genre}"
  cp "${cached}" "${DEST}/${genre}/${name}"
  printf '%s / %s\n  %s - %s\n  License: %s (%s)\n  Source:  %s\n\n' \
    "${genre}" "${name}" "${artist}" "${title}" "${license}" "${license_url}" "${source_url}" >> "${credits}"
  n=$((n + 1))
done < "${LIST}"

echo "demo-music: ${n} tracks in ${DEST} ($(du -sh "${DEST}" | cut -f1))"
