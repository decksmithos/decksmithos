#!/usr/bin/env bash
# One-time move of the DecksmithOS work from the user ady to the service user
# claude. Run as root after reading it:
#
#   sudo /shared/decksmithos/decksmithos/tools/migrate-to-claude.sh [--with-signing-key]
#
# What it does (nothing is deleted):
#  1. installs qemu-utils (qemu-img for the build VM)
#  2. /shared/decksmithos: group decksmithos, group-writable, setgid
#     directories (new files get the group)
#  3. lingering for claude (its user services run without a login)
#  4. copies the Claude Code memory of this project from ady to claude
#  5. git for claude: ady's name and e-mail, the repository as safe.directory
#  6. an SSH key for claude (if it has none) and prints it, for GitHub and the
#     dev device
#  7. with --with-signing-key: copies the update signing key and its
#     passphrase file to claude (otherwise updates are signed as ady)
set -Eeuo pipefail

SHARED="/shared/decksmithos"
REPO="${SHARED}/decksmithos"
FROM_USER="ady"
TO_USER="claude"
GROUP="decksmithos"
PROJECT=".claude/projects/-shared-decksmithos"

die() { echo "migrate: ERROR: $*" >&2; exit 1; }
log() { echo "migrate: $*"; }

[[ "$(id -u)" == 0 ]] || die "run as root"
with_key=0
[[ "${1:-}" == --with-signing-key ]] && with_key=1

from_home="$(getent passwd "${FROM_USER}" | cut -d: -f6)"
to_home="$(getent passwd "${TO_USER}" | cut -d: -f6)"
[[ -n "${from_home}" && -d "${from_home}" ]] || die "no home for ${FROM_USER}"
[[ -n "${to_home}" && -d "${to_home}" ]] || die "no home for ${TO_USER}"
[[ "${to_home}" != / && "${from_home}" != / ]] || die "odd home directories"
getent group "${GROUP}" >/dev/null || die "group ${GROUP} missing"
id -nG "${TO_USER}" | tr ' ' '\n' | grep -qx kvm || die "${TO_USER} is not in the group kvm"
[[ -d "${REPO}/.git" ]] || die "${REPO} is not the repository"

log "1. qemu-utils"
command -v qemu-img >/dev/null || apt-get install -y qemu-utils

log "2. ${SHARED}: group ${GROUP}, group-writable, setgid directories"
chgrp -R --no-dereference "${GROUP}" -- "${SHARED}"
chmod -R g+rwX -- "${SHARED}"
find "${SHARED}" -xdev -type d -exec chmod g+s -- {} +

log "3. lingering for ${TO_USER}"
loginctl enable-linger "${TO_USER}"

log "4. Claude Code memory of the project"
if [[ -d "${from_home}/${PROJECT}/memory" ]]; then
  install -d -o "${TO_USER}" -g "${TO_USER}" -m 700 \
    "${to_home}/.claude" "${to_home}/.claude/projects" "${to_home}/${PROJECT}"
  if [[ -e "${to_home}/${PROJECT}/memory" ]]; then
    log "   ${to_home}/${PROJECT}/memory exists: left as it is"
  else
    cp -a -- "${from_home}/${PROJECT}/memory" "${to_home}/${PROJECT}/memory"
    chown -R "${TO_USER}:${TO_USER}" -- "${to_home}/${PROJECT}/memory"
  fi
fi

log "5. git for ${TO_USER}"
name="$(sudo -u "${FROM_USER}" git config --global user.name || true)"
email="$(sudo -u "${FROM_USER}" git config --global user.email || true)"
[[ -n "${name}" ]] && sudo -u "${TO_USER}" git config --global user.name "${name}"
[[ -n "${email}" ]] && sudo -u "${TO_USER}" git config --global user.email "${email}"
sudo -u "${TO_USER}" git config --global --add safe.directory "${REPO}"

log "6. SSH key of ${TO_USER}"
install -d -o "${TO_USER}" -g "${TO_USER}" -m 700 "${to_home}/.ssh"
if [[ ! -f "${to_home}/.ssh/id_ed25519" ]]; then
  sudo -u "${TO_USER}" ssh-keygen -q -t ed25519 -N "" -C "${TO_USER}@$(hostname)" \
    -f "${to_home}/.ssh/id_ed25519"
fi

if [[ "${with_key}" == 1 ]]; then
  log "7. update signing key"
  for f in decksmithos_ed25519 decksmithos_ed25519.pub decksmithos.pass; do
    if [[ -f "${from_home}/.ssh/${f}" && ! -e "${to_home}/.ssh/${f}" ]]; then
      install -o "${TO_USER}" -g "${TO_USER}" -m 600 -- "${from_home}/.ssh/${f}" "${to_home}/.ssh/${f}"
    fi
  done
else
  log "7. signing key not copied (updates are signed as ${FROM_USER})"
fi

log "done. Public key of ${TO_USER} (GitHub: Settings > SSH keys; dev device: /root/.ssh/authorized_keys):"
cat "${to_home}/.ssh/id_ed25519.pub"
cat <<NEXT

Next, as ${TO_USER} (sudo -iu ${TO_USER}):
  gh auth login                                   # publishing the Mixxx packages
  ${REPO}/tools/buildvm/install-user-services.sh  # build VM and Claude Code services
  ${REPO}/tools/buildvm/create-vm.sh              # the build VM (a few minutes)
NEXT
