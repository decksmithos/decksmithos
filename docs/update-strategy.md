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

DecksmithOS has two complete slots, each a boot partition plus a root
filesystem (A = boot_A + rootfs_A, B = boot_B + rootfs_B), selected by
the Raspberry Pi bootloader's tryboot mode (see disk-layout.md).

Update procedure:

1. Determine the running slot (`decksmithos-slot`)
2. Write the new boot files and root filesystem to the other slot
3. `decksmithos-slot try`: reboot once into the new slot
4. Check that the new slot works, then `decksmithos-slot commit`
5. If it fails or is not committed, the next reboot or power cycle
   returns to the previous slot automatically

This provides safe rollback capability.

---

## Update Safety

All update mechanisms must:
- preserve the storage partition
- avoid corrupting user data
- allow recovery from failed updates
