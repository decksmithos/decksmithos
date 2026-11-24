#!/bin/bash
# Run a command (or a shell) as root on the DecksmithOS dev device, with the
# SSH key of the current user (its public key in /root/.ssh/authorized_keys of
# the device). The release profile has no SSH.
#   tools/dev-ssh.sh [command...]      DECKSMITHOS_DEV_IP (default 172.16.0.238)
# The device's host key is kept apart from ~/.ssh/known_hosts (a reflash
# changes it): after a reflash, ssh-keygen -f ~/.ssh/known_hosts.decksmithos-dev -R <ip>
exec ssh -o ConnectTimeout=10 -o BatchMode=yes \
  -o UserKnownHostsFile="${HOME}/.ssh/known_hosts.decksmithos-dev" \
  -o StrictHostKeyChecking=accept-new \
  "root@${DECKSMITHOS_DEV_IP:-172.16.0.238}" "$@"
