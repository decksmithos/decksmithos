#!/usr/bin/env bash
# Build a DecksmithOS image in the build VM, from a commit of this
# repository, and sign its update file on the host.
#
#   tools/buildvm/build-in-vm.sh [--keep-running] [commit] [release|dev]
#
#   commit    default HEAD (uncommitted changes are not built: commit first)
#   profile   default release
#
# The VM is started if needed, gets the commit (a git bundle, so unpushed
# commits work too), runs build/build.sh there as its own root, and is
# stopped again afterwards (--keep-running leaves it on). The image, its
# .bmap/.xz and the unsigned update come back to build/output-vm/<profile>/;
# the update is signed here (build/sign-update.sh) with the key of the host
# user, which never enters the VM. Nothing on the host runs as root.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

keep_running=0
if [[ "${1:-}" == --keep-running ]]; then
  keep_running=1
  shift
fi
commit="$(git -C "${REPO_DIR}" rev-parse --verify "${1:-HEAD}^{commit}")" \
  || vm_die "unknown commit '${1:-HEAD}'"
profile="${2:-release}"
case "${profile}" in
  release) build_script="./build.sh" ;;
  dev) build_script="./build-dev.sh" ;;
  *) vm_die "profile must be release or dev, not '${profile}'" ;;
esac
short="$(git -C "${REPO_DIR}" rev-parse --short "${commit}")"
out_dir="${REPO_DIR}/build/output-vm/${profile}"
mkdir -p "${out_dir}"
log_file="${out_dir}/build-${short}.log"

was_running=0
[[ "$("${SCRIPT_DIR}/vm.sh" status)" == running ]] && was_running=1
finish() {
  local status=$?
  if [[ "${keep_running}" == 0 && "${was_running}" == 0 ]]; then
    "${SCRIPT_DIR}/vm.sh" stop || true
  fi
  [[ "${status}" == 0 ]] || vm_log "build failed (exit ${status}), log: ${log_file}"
}
trap finish EXIT

"${SCRIPT_DIR}/vm.sh" start

# --- The commit into the VM ----------------------------------------------------------
vm_log "sending ${short} to the VM"
ref="refs/buildvm/${short}"
git -C "${REPO_DIR}" update-ref "${ref}" "${commit}"
bundle="$(mktemp)"
git -C "${REPO_DIR}" bundle create -q "${bundle}" "${ref}" --tags
git -C "${REPO_DIR}" update-ref -d "${ref}"
vm_ssh 'rm -rf ~/src ~/src.bundle'
vm_ssh 'cat > ~/src.bundle' < "${bundle}"
rm -f "${bundle}"
# git clone takes only branches and tags from a bundle: fetch the ref by name
vm_ssh "git init -q ~/src && git -C ~/src fetch -q ~/src.bundle '${ref}:${ref}' \
  && git -C ~/src -c advice.detachedHead=false checkout -q ${commit}"

# --- Build (as root inside the VM only) ----------------------------------------------
vm_log "building ${profile} of ${short} in the VM (log: ${log_file})"
vm_ssh "cd ~/src/build && DECKSMITHOS_MAKE_UPDATE=unsigned ${build_script} </dev/null" \
  2>&1 | tee "${log_file}"
[[ "${PIPESTATUS[0]}" == 0 ]] || vm_die "the build failed in the VM"

# --- Results back ----------------------------------------------------------------------
vm_log "copying the results"
files="$(vm_ssh "cd ~/src/build/output && ls decksmithos-${profile}.img decksmithos-${profile}.bmap \
  decksmithos-${profile}.img.xz decksmithos-${profile}.img.xz.sha256 \
  decksmithos-${profile}-*.unsigned 2>/dev/null || true")"
[[ -n "${files}" ]] || vm_die "no results in the VM"
for f in ${files}; do
  vm_scp_from "src/build/output/${f}" "${out_dir}/${f}"
done

# --- Sign here ---------------------------------------------------------------------------
for unsigned in "${out_dir}"/decksmithos-"${profile}"-*.unsigned; do
  [[ -f "${unsigned}" ]] || continue
  "${REPO_DIR}/build/sign-update.sh" "${unsigned}" && rm -f "${unsigned}"
done
vm_log "done: $(ls "${out_dir}" | tr '\n' ' ')"
