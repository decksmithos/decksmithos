# Build VM

DecksmithOS images are built as root (pi-gen: debootstrap, chroot, loop
devices, binfmt). A slip in a build script must not touch the host, so the
image builds run in a KVM virtual machine, started only for a build.

| File | |
|---|---|
| `create-vm.sh` | once: Debian trixie cloud image, cloud-init (user `builder`, key, pi-gen and Docker packages), snapshot `clean` |
| `vm.sh` | `start`, `stop`, `status`, `ssh`, `reset` (back to `clean`) |
| `build-in-vm.sh [--keep-running] [commit] [release\|dev]` | a commit (git bundle) built in the VM, results in `build/output-vm/<profile>/`, the update signed on the host (`build/sign-update.sh`) |
| `mixxx-in-vm.sh [--keep-running] [--nocheck] [src-dir] [out-dir]` | Mixxx test build (amd64) of `build/mixxx` of the working tree in a `debian:trixie` container in the VM, packages and log in `build/output-vm/mixxx/<version>/`; one build at a time (`build.lock`) |
| `decksmithos-buildvm.service` | systemd user unit of the VM (not enabled: started on demand) |
| `claude-decksmithos.service` | systemd user unit: Claude Code (conversation `decksmithos`) in tmux session `decksmithos` on socket `decksmithos` (`tmux -L decksmithos attach -t decksmithos`) |
| `install-user-services.sh` | installs both units for the current user |

Host setup (once, as root): packages `qemu-system-x86 qemu-utils xorriso
tmux socat`; `usermod -aG kvm,decksmithos claude`; `loginctl enable-linger
claude`. Everything else runs as `claude` without sudo. The VM: 8 cores and
6 GB while it runs (`DECKSMITHOS_VM_CPUS`, `DECKSMITHOS_VM_MEMORY_MB`), a
copy-on-write disk of at most 80 GB, QEMU user networking with SSH on
127.0.0.1:2222 only. The update signing key stays on the host.
