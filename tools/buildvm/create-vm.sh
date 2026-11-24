#!/usr/bin/env bash
# Create the DecksmithOS build VM (once): a Debian trixie cloud image under
# KVM with what pi-gen and the Mixxx package build need. The builds run as
# root inside the VM only; a mistake in a build script can damage the VM,
# never the host. Run as the user that will run the builds (claude); needs
# the groups kvm and nothing else on the host (no sudo).
#
#   tools/buildvm/create-vm.sh
#
# Host packages: qemu-system-x86, qemu-utils (qemu-img), xorriso, openssh-client.
# Afterwards: tools/buildvm/vm.sh start|stop|ssh|status, and
# tools/buildvm/build-in-vm.sh <commit> [dev|release].
#
# The disk is a copy-on-write layer over the Debian image, with an internal
# snapshot "clean" taken after provisioning: tools/buildvm/vm.sh reset goes
# back to it in seconds.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

for tool in qemu-system-x86_64 qemu-img xorriso ssh ssh-keygen curl sha512sum; do
  command -v "${tool}" >/dev/null || vm_die "${tool} is missing on the host"
done
[[ -r /dev/kvm && -w /dev/kvm ]] || vm_die "no access to /dev/kvm (is $(id -un) in the group kvm?)"
[[ -e "${VM_DISK}" ]] && vm_die "${VM_DISK} exists already (remove ${VM_DIR} to start over)"

mkdir -p "${VM_DIR}"
chmod 700 "${VM_DIR}"

# --- Debian cloud image, verified ------------------------------------------------
if [[ ! -f "${VM_BASE}" ]]; then
  vm_log "downloading the Debian trixie cloud image"
  curl -fL --progress-bar -o "${VM_BASE}.part" "${BASE_URL}/$(basename "${VM_BASE}")"
  curl -fsSL -o "${VM_DIR}/SHA512SUMS" "${BASE_URL}/SHA512SUMS"
  expected="$(awk -v f="$(basename "${VM_BASE}")" '$2 == f {print $1}' "${VM_DIR}/SHA512SUMS")"
  [[ -n "${expected}" ]] || vm_die "$(basename "${VM_BASE}") is not in SHA512SUMS"
  actual="$(sha512sum "${VM_BASE}.part" | awk '{print $1}')"
  [[ "${actual}" == "${expected}" ]] || vm_die "checksum mismatch of the Debian image"
  mv "${VM_BASE}.part" "${VM_BASE}"
fi

# --- SSH key of the host user for the VM -----------------------------------------
if [[ ! -f "${VM_KEY}" ]]; then
  mkdir -p "$(dirname "${VM_KEY}")"
  ssh-keygen -q -t ed25519 -N "" -C "${VM_NAME}" -f "${VM_KEY}"
fi

# --- Disk: copy-on-write over the base image ----------------------------------------
qemu-img create -q -f qcow2 -F qcow2 -b "${VM_BASE}" "${VM_DISK}" "${VM_DISK_SIZE}"

# --- cloud-init: user, key, packages ---------------------------------------------------
seed="$(mktemp -d)"
trap 'rm -rf "${seed}"' EXIT
cat > "${seed}/meta-data" <<META
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
META
cat > "${seed}/user-data" <<USER
#cloud-config
users:
  - name: ${VM_USER}
    groups: [sudo, docker]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat "${VM_KEY}.pub")
ssh_pwauth: false
package_update: true
packages:
  # pi-gen (its "depends" file) and the DecksmithOS build
  - quilt
  - parted
  - qemu-user-binfmt
  - debootstrap
  - zerofree
  - zip
  - dosfstools
  - e2fsprogs
  - libcap2-bin
  - rsync
  - xz-utils
  - curl
  - xxd
  - file
  - git
  - kmod
  - bc
  - gpg
  - pigz
  - arch-test
  - jq
  - zstd
  - bmap-tools
  - openssh-client
  # the Mixxx package build (build/mixxx/build-mixxx-deb.sh in a container)
  - docker.io
growpart:
  mode: auto
  devices: ["/"]
power_state:
  mode: poweroff
  condition: true
USER
xorriso -as mkisofs -quiet -output "${VM_SEED}" -volid cidata -joliet -rock \
  "${seed}/user-data" "${seed}/meta-data"

# --- First boot: cloud-init provisions and powers off ---------------------------------
vm_log "first boot: installing packages (a few minutes), the VM powers off by itself"
"${SCRIPT_DIR}/vm.sh" run-foreground --seed

# The seed is not needed any more: later boots do not change the VM
rm -f "${VM_SEED}"
qemu-img snapshot -c clean "${VM_DISK}"
vm_log "created ${VM_DISK} (snapshot 'clean'); start it with: ${SCRIPT_DIR}/vm.sh start"
