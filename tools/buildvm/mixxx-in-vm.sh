#!/usr/bin/env bash
# Build the DecksmithOS Mixxx packages in the build VM (local test builds;
# the published arm64 packages come from .github/workflows/mixxx-deb.yml).
#
#   tools/buildvm/mixxx-in-vm.sh [--keep-running] [--nocheck] [src-dir] [out-dir]
#
#   src-dir   a directory like build/mixxx (build-mixxx-deb.sh, mixxx.conf,
#             patches/), default build/mixxx of the working tree, so that
#             uncommitted patches can be tried before they are published
#   out-dir   default build/output-vm/mixxx/<package version>
#   --nocheck skip the upstream test suite (MIXXX_NOCHECK=1)
#
# build-mixxx-deb.sh runs as root in a debian:trixie container inside the VM
# (amd64, ALLOW_ANY_ARCH=1), never on the host. Its ccache stays in the VM
# (/var/cache/decksmithos-mixxx-ccache). The VM is started if needed and
# stopped afterwards unless it was running already or --keep-running.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

keep_running=0
nocheck=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --keep-running) keep_running=1 ;;
    --nocheck) nocheck=1 ;;
    *) vm_die "unknown option $1" ;;
  esac
  shift
done
src_dir="$(cd "${1:-${REPO_DIR}/build/mixxx}" && pwd)"
for f in build-mixxx-deb.sh mixxx.conf patches; do
  [[ -e "${src_dir}/${f}" ]] || vm_die "${src_dir} has no ${f}"
done
version="$(. "${src_dir}/mixxx.conf" && echo "${MIXXX_SOURCE_VERSION}${MIXXX_LOCAL_SUFFIX}")"
out_dir="${2:-${REPO_DIR}/build/output-vm/mixxx/${version}}"
mkdir -p "${out_dir}"
log_file="${out_dir}/build.log"

# One build at a time in the VM (an image build and a Mixxx build would
# compete for its memory, and the first to finish would stop the VM)
mkdir -p "${VM_DIR}"
exec 9>"${VM_DIR}/build.lock"
if ! flock -n 9; then
  vm_log "another build is using the VM: waiting"
  flock 9
fi

# Parallel jobs: the VM's cores, but about 1.2 GB of RAM per compiler
jobs=$(( VM_MEMORY_MB / 1200 ))
(( jobs > VM_CPUS )) && jobs=${VM_CPUS}
(( jobs < 1 )) && jobs=1

was_running=0
[[ "$("${SCRIPT_DIR}/vm.sh" status)" == running ]] && was_running=1
finish() {
  local status=$?
  if [[ "${keep_running}" == 0 && "${was_running}" == 0 ]]; then
    "${SCRIPT_DIR}/vm.sh" stop || true
  fi
  [[ "${status}" == 0 ]] || vm_log "Mixxx build failed (exit ${status}), log: ${log_file}"
}
trap finish EXIT

"${SCRIPT_DIR}/vm.sh" start

vm_log "sending ${src_dir} to the VM"
vm_ssh 'sudo rm -rf ~/mixxx-src ~/mixxx-out && mkdir ~/mixxx-src ~/mixxx-out'
tar -C "${src_dir}" -cf - build-mixxx-deb.sh mixxx.conf patches \
  | vm_ssh 'tar -C ~/mixxx-src -xf -'

vm_log "building Mixxx ${version} in the VM (${jobs} jobs, log: ${log_file})"
env_args="-e ALLOW_ANY_ARCH=1 -e CCACHE_DIR=/ccache"
[[ "${nocheck}" == 1 ]] && env_args+=" -e MIXXX_NOCHECK=1"
# --cpuset-cpus limits nproc, which build-mixxx-deb.sh uses for parallel=
vm_ssh "sudo mkdir -p /var/cache/decksmithos-mixxx-ccache && \
  sudo docker run --rm --cpuset-cpus=0-$(( jobs - 1 )) ${env_args} \
    -v \"\${HOME}/mixxx-src:/src:ro\" -v \"\${HOME}/mixxx-out:/out\" \
    -v /var/cache/decksmithos-mixxx-ccache:/ccache \
    debian:trixie /src/build-mixxx-deb.sh /out </dev/null" 2>&1 | tee "${log_file}"
[[ "${PIPESTATUS[0]}" == 0 ]] || vm_die "the Mixxx build failed in the VM"

vm_log "copying the packages"
files="$(vm_ssh 'cd ~/mixxx-out && ls')"
[[ -n "${files}" ]] || vm_die "no packages in the VM"
for f in ${files}; do
  vm_scp_from "mixxx-out/${f}" "${out_dir}/${f}"
done
(cd "${out_dir}" && sha256sum -c --quiet SHA256SUMS) || vm_die "checksums of the copied files do not match"
grep -E '% tests passed|tests failed out of' "${log_file}" | tail -1 || true
vm_log "done: ${out_dir}"
