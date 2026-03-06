# Update Strategy

DecksmithOS supports two update mechanisms.

---

## Initial Installation

The initial installation uses a complete disk image:
decksmithos.img

This image includes:
- boot partition
- root filesystem
- partition layout

The image can be written directly to storage using standard tools.

Example:
dd
Raspberry Pi Imager
balenaEtcher

---

## System Updates

After installation, updates should avoid rewriting the entire disk.

Two strategies are supported.

---

## Strategy 1 — Overlay Updates

Updates contain only modified system files.

Package format:
decksmithos-update.tar

Update process:
1. Stop DJ services
2. Apply filesystem overlay
3. Install/remove packages
4. Restart services

This method is simple and efficient.

---

## Strategy 2 — A/B Root Filesystem

DecksmithOS supports dual root partitions:
rootfs_A
rootfs_B

Update procedure:

1. Determine the currently active slot (A or B)
2. Write the new root filesystem to the inactive slot
3. Switch boot target to the updated slot
4. Reboot
5. If boot fails, roll back by switching back to the previous slot

This provides safe rollback capability.

---

## Update Safety

All update mechanisms must:
- preserve the storage partition
- avoid corrupting user data
- allow recovery from failed updates
