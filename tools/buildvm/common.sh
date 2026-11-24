# Shared settings of the DecksmithOS build VM (sourced by the other scripts).
# Everything lives in the home of the user that runs it (claude): no root on
# the host. Override with environment variables.
# A login through sudo -iu or su has no XDG_RUNTIME_DIR: systemctl --user
# needs it to reach the user's service manager (running thanks to lingering)
if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/$(id -u)" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi
VM_NAME="decksmithos-buildvm"
VM_DIR="${DECKSMITHOS_VM_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/${VM_NAME}}"
VM_DISK="${VM_DIR}/disk.qcow2"
VM_BASE="${VM_DIR}/debian-13-genericcloud-amd64.qcow2"
VM_SEED="${VM_DIR}/seed.iso"
VM_QMP="${VM_DIR}/qmp.sock"
VM_KEY="${DECKSMITHOS_VM_KEY:-${HOME}/.ssh/${VM_NAME}_ed25519}"
VM_SSH_PORT="${DECKSMITHOS_VM_SSH_PORT:-2222}"
VM_CPUS="${DECKSMITHOS_VM_CPUS:-8}"
VM_MEMORY_MB="${DECKSMITHOS_VM_MEMORY_MB:-6144}"
VM_DISK_SIZE="${DECKSMITHOS_VM_DISK_SIZE:-80G}"
VM_USER="builder"
BASE_URL="https://cloud.debian.org/images/cloud/trixie/latest"

vm_log() { echo "${VM_NAME}: $*"; }
vm_die() { echo "${VM_NAME}: ERROR: $*" >&2; exit 1; }

vm_ssh() {
  ssh -i "${VM_KEY}" -p "${VM_SSH_PORT}" -o BatchMode=yes -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="${VM_DIR}/known_hosts" \
    -o ServerAliveInterval=20 "${VM_USER}@127.0.0.1" "$@"
}

vm_scp_from() {
  scp -i "${VM_KEY}" -P "${VM_SSH_PORT}" -o BatchMode=yes \
    -o UserKnownHostsFile="${VM_DIR}/known_hosts" "${VM_USER}@127.0.0.1:$1" "$2"
}
