#!/usr/bin/env bash
# Make patches/0000-mixxx-<branch>-branch-<sha>.patch: the bug fixes on an
# upstream Mixxx stable branch since the release the Debian package is based on,
# so that DecksmithOS does not have to wait for the next upstream release and
# for Debian to package it.
#
# Usage: build/mixxx/make-stable-patch.sh [<branch> [<commit>]]
#   branch  upstream stable branch (default 2.5)
#   commit  commit on that branch (default: its current head)
#
# Runs on the build host (no root): git, wget, dpkg-source, patch, diff.
# The patch is the diff <release tag>..<commit> limited to src/, res/ (without
# res/translations: binary .qm files), lib/xwax/, cmake/ and CMakeLists.txt,
# made against the Debian source with Debian's patches applied (it is applied
# after them). The version in CMakeLists.txt stays the release's. Afterwards,
# check that patches/0001-* and later still apply (the script tries) and build.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mixxx.conf
. "${SCRIPT_DIR}/mixxx.conf"

BRANCH="${1:-2.5}"
UPSTREAM="https://github.com/mixxxdj/mixxx.git"
RELEASE="${MIXXX_SOURCE_VERSION%%+*}"   # 2.5.6+dfsg-3 -> 2.5.6
DSC="mixxx_${MIXXX_SOURCE_VERSION}.dsc"
POOL="https://deb.debian.org/debian/pool/main/m/mixxx"
SNAPSHOT="https://snapshot.debian.org/archive/debian/${MIXXX_SNAPSHOT_TIMESTAMP}/pool/main/m/mixxx"

log() { printf '[make-stable-patch] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mixxx-stable.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
cd "${WORK}"

log "Fetching upstream ${BRANCH} and tag ${RELEASE}"
git init -q up
git -C up fetch -q --filter=blob:none "${UPSTREAM}" "refs/tags/${RELEASE}:refs/tags/${RELEASE}" \
  "refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}"
COMMIT="$(git -C up rev-parse "${2:-origin/${BRANCH}}^{commit}")"
git -C up merge-base --is-ancestor "${RELEASE}" "${COMMIT}" \
  || die "${COMMIT} does not contain ${RELEASE}"
COUNT="$(git -C up rev-list --no-merges --count "${RELEASE}..${COMMIT}")"
log "${RELEASE}..${COMMIT:0:10}: ${COUNT} non-merge commits"

log "Fetching Debian source ${MIXXX_SOURCE_VERSION}"
fetch() {
  local base="$1" f
  wget -q "${base}/${DSC}" || return 1
  for f in $(awk '/^Files:/{f=1; next} /^[^ ]/{f=0} f{print $3}' "${DSC}"); do
    wget -q "${base}/${f}" || return 1
  done
}
fetch "${POOL}" || { rm -f ./*.dsc ./*.tar.*; fetch "${SNAPSHOT}"; } || die "cannot fetch ${DSC}"
# The CI build verifies the signature (dget); here only the patch is made.
dpkg-source --no-check -x "${DSC}" a >/dev/null
cp -a a b

git -C up diff "${RELEASE}" "${COMMIT}" -- src res lib/xwax cmake CMakeLists.txt \
  ':!res/translations' > upstream.diff
(cd b && patch -p1 -s --no-backup-if-mismatch < ../upstream.diff) \
  || die "the ${BRANCH} diff does not apply to the Debian source (see above)"
sed -i "s/^project(mixxx VERSION [0-9.]*)/project(mixxx VERSION ${RELEASE})/" b/CMakeLists.txt

NAME="0000-mixxx-${BRANCH}-branch-${COMMIT:0:10}.patch"
{
  printf '%s\n' \
    "Description: Bug fixes from the upstream ${BRANCH} branch since ${RELEASE}" \
    " git diff ${RELEASE}..${COMMIT} (mixxxdj/mixxx branch ${BRANCH}," \
    " ${COUNT} non-merge commits), limited to src/, res/ (without" \
    " res/translations), lib/xwax/, cmake/ and CMakeLists.txt. The version" \
    " stays ${RELEASE}. Made by build/mixxx/make-stable-patch.sh against the" \
    " Debian source with Debian's patches applied." \
    "Origin: upstream, https://github.com/mixxxdj/mixxx/compare/${RELEASE}...${COMMIT}" \
    "Forwarded: not-needed" \
    "Last-Update: $(date -u +%F)" \
    "---"
  # GNU diff quotes names with spaces ("a/res/controllers/Reloop Beatpad...");
  # dpkg-source rejects C-style quoted names. The tab before the timestamp
  # already delimits the name, so drop the quotes.
  diff -Naur a b | sed -E \
    -e 's@^(---|\+\+\+) "([^"]*)"\t@\1 \2\t@' \
    -e 's@^diff -Naur "([^"]*)" "([^"]*)"$@diff -Naur \1 \2@' || true
} > "${NAME}"
grep -qE '^(---|\+\+\+) "' "${NAME}" && die "quoted (escaped) file names left in ${NAME}"

# Each DecksmithOS patch, in series order, on top of the stable branch:
#   applies          -> ok (applied, so the next one sees it)
#   applies reversed -> its change is already upstream: delete the patch
#   partly reversed  -> part of it is upstream: drop those hunks
#   otherwise        -> conflicts: refresh its context
log "Checking the DecksmithOS patches on top of ${BRANCH} ${COMMIT:0:10}"
cp -a b c
ok=1
for p in "${SCRIPT_DIR}"/patches/*.patch; do
  name="${p##*/}"
  [[ "${name}" == 0000-* ]] && continue
  if (cd c && patch -p1 -s -f --no-backup-if-mismatch --dry-run < "${p}" >/dev/null 2>&1); then
    (cd c && patch -p1 -s --no-backup-if-mismatch < "${p}")
    log "  ok              ${name}"
  elif (cd c && patch -p1 -s -f -R --no-backup-if-mismatch --dry-run < "${p}" >/dev/null 2>&1); then
    log "  ALREADY UPSTREAM ${name}: ${BRANCH} contains this change; delete the patch"
    ok=0
  else
    out="$(cd c && patch -p1 -f -N --no-backup-if-mismatch --dry-run < "${p}" 2>&1 || true)"
    failed="$(grep -c 'FAILED at' <<< "${out}" || true)"
    reversed="$(grep -c 'Reversed (or previously applied)' <<< "${out}" || true)"
    if (( reversed > 0 )); then
      log "  PARTLY UPSTREAM ${name}: ${reversed} file(s) already changed upstream, ${failed} hunk(s) fail"
    else
      log "  CONFLICT        ${name}: ${failed} hunk(s) fail; refresh its context"
    fi
    grep -E 'FAILED at|Reversed|^checking file' <<< "${out}" | sed 's/^/      /' >&2
    ok=0
  fi
done

rm -f "${SCRIPT_DIR}"/patches/0000-*.patch
cp "${NAME}" "${SCRIPT_DIR}/patches/${NAME}"
log "wrote patches/${NAME} ($(grep -c '^diff ' "${NAME}") files)"
(( ok )) || die "fix the patches listed above before building"
