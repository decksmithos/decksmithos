#!/usr/bin/env bash
# Install the user services of tools/buildvm for the current user (claude):
# the build VM service (started on demand) and the Claude Code session
# (enabled, starts at boot with lingering). No root needed.
#
#   tools/buildvm/install-user-services.sh
#
# Once, as root:  usermod -aG kvm,decksmithos claude; loginctl enable-linger claude
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

units="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
mkdir -p "${units}" "${VM_DIR}/bin"
# The service runs a copy of the VM scripts outside the repository, so that a
# change in the repository does not alter a running VM's unit
install -m 755 "${SCRIPT_DIR}/vm.sh" "${SCRIPT_DIR}/common.sh" "${VM_DIR}/bin/"
install -m 644 "${SCRIPT_DIR}/decksmithos-buildvm.service" "${SCRIPT_DIR}/claude-decksmithos.service" "${units}/"
systemctl --user daemon-reload
systemctl --user enable claude-decksmithos.service
echo "Installed. Start the session now with: systemctl --user start claude-decksmithos.service"
