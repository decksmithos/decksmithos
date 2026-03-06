# Disk Layout

DecksmithOS is designed for SSD storage with a firmware-style partition layout.

The layout prioritizes system reliability and efficient storage usage.

---

## Partition Table

Disk
│
├─ boot        (FAT32)
├─ rootfs_A    (ext4)
├─ rootfs_B    (ext4)
└─ storage     (ext4)

---

## Boot Partition

Filesystem:
FAT32


Typical size:
256 MB

Contents:
- bootloader
- kernel
- device tree files
- boot configuration

---

## Root Filesystems (A/B)

DecksmithOS uses two root filesystem partitions to enable safe, firmware-style updates.

Partitions:

- `rootfs_A` (active or inactive depending on current boot target)
- `rootfs_B` (the other slot)

Typical size (per rootfs slot):
ext4

Typical size:
3 GB
￼
Contents:
- operating system
- DecksmithOS runtime
- Mixxx installation

Mount options prioritize reliability over performance.

---

## Storage Partition

Filesystem:
ext4

Purpose:

- music library
- Mixxx database
- recordings
- exported sets

This partition consumes most of the SSD capacity.

---

## SSD Overprovisioning

To improve SSD endurance and garbage collection efficiency, approximately:
15% of the SSD capacity

should remain **unallocated**.

This space is intentionally left outside all partitions.

---

## Trim Support

DecksmithOS uses periodic TRIM operations via:
fstrim.timer

Continuous `discard` mount options are avoided to prevent performance degradation.
