#!/usr/bin/env bash
# Run and control the DecksmithOS build VM (created by create-vm.sh).
#
#   vm.sh start            start it in the background (systemd user service
#                          decksmithos-buildvm.service if installed) and wait
#                          for SSH
#   vm.sh stop             shut it down cleanly (ACPI power button)
#   vm.sh status           running or not
#   vm.sh ssh [command]    a shell or a command in the VM
#   vm.sh reset            back to the snapshot "clean" (VM stopped)
#   vm.sh run-foreground   run QEMU in the foreground (used by the service)
#
# Resources: VM_CPUS cores and VM_MEMORY_MB of RAM while it runs, nothing
# when it is stopped (build-in-vm.sh starts it and stops it again). The
# network is QEMU's user mode: the VM reaches the internet, and only its SSH
# port is forwarded to 127.0.0.1 on the host.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

running() {
  [[ -S "${VM_QMP}" ]] && pgrep -f -- "-name ${VM_NAME}" >/dev/null
}

qmp() {
  # One QMP command over the monitor socket
  printf '{"execute":"qmp_capabilities"}\n{"execute":"%s"}\n' "$1" \
    | timeout 5 socat - "UNIX-CONNECT:${VM_QMP}" >/dev/null 2>&1 \
    || python3 - "${VM_QMP}" "$1" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.settimeout(5)
s.recv(4096)
for cmd in ("qmp_capabilities", sys.argv[2]):
    s.sendall((json.dumps({"execute": cmd}) + "\n").encode()); s.recv(4096)
PY
}

wait_ssh() {
  local i
  for i in $(seq 1 90); do
    if vm_ssh true 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  vm_die "no SSH to the VM after 3 minutes"
}

case "${1:-}" in
  run-foreground)
    [[ -f "${VM_DISK}" ]] || vm_die "no VM: run create-vm.sh first"
    extra=()
    if [[ "${2:-}" == --seed ]]; then
      extra+=(-drive "file=${VM_SEED},media=cdrom,readonly=on")
    fi
    rm -f "${VM_QMP}"
    exec qemu-system-x86_64 \
      -name "${VM_NAME}" \
      -machine q35,accel=kvm -cpu host \
      -smp "${VM_CPUS}" -m "${VM_MEMORY_MB}" \
      -device virtio-balloon-pci \
      -drive "file=${VM_DISK},if=virtio,discard=unmap,detect-zeroes=unmap,cache=none,aio=native" \
      -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${VM_SSH_PORT}-:22" \
      -device virtio-net-pci,netdev=net0 \
      -device virtio-rng-pci \
      -qmp "unix:${VM_QMP},server,nowait" \
      -display none -serial "file:${VM_DIR}/console.log" \
      "${extra[@]}"
    ;;
  start)
    if running; then
      vm_log "already running"
    elif systemctl --user cat "${VM_NAME}.service" >/dev/null 2>&1; then
      systemctl --user start "${VM_NAME}.service"
    else
      nohup "$0" run-foreground >/dev/null 2>&1 &
    fi
    wait_ssh
    vm_log "running (ssh -p ${VM_SSH_PORT} ${VM_USER}@127.0.0.1)"
    ;;
  stop)
    if ! running; then
      vm_log "not running"
      exit 0
    fi
    qmp system_powerdown || true
    for i in $(seq 1 60); do
      running || break
      sleep 2
    done
    if running; then
      vm_log "did not power off in 2 minutes: stopping QEMU"
      qmp quit || pkill -f -- "-name ${VM_NAME}" || true
    fi
    systemctl --user stop "${VM_NAME}.service" 2>/dev/null || true
    vm_log "stopped"
    ;;
  status)
    running && echo running || echo stopped
    ;;
  ssh)
    shift
    vm_ssh "$@"
    ;;
  reset)
    running && vm_die "stop the VM first"
    qemu-img snapshot -a clean "${VM_DISK}"
    vm_log "back to the snapshot 'clean'"
    ;;
  *)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
