# Disk Layout

DecksmithOS is designed for SSD storage with a firmware-style partition layout.

The layout prioritizes system reliability and efficient storage usage.

---

## Partition Table

GPT (requires a GPT-capable bootloader: Pi 5 / CM5; Pi 4 / CM4 with an
updated EEPROM).

```text
Disk (GPT)
├─ p1 autoboot  FAT16  PARTLABEL=autoboot   32 MiB   autoboot.txt only
├─ p2 boot_A    FAT32  PARTLABEL=boot_A    512 MiB   firmware/kernel/config of slot A
├─ p3 boot_B    FAT32  PARTLABEL=boot_B    512 MiB   firmware/kernel/config of slot B
├─ p4 rootfs_A  ext4   PARTLABEL=rootfs_A    4 GiB   mounted read-only (overlay)
├─ p5 rootfs_B  ext4   PARTLABEL=rootfs_B    4 GiB   mounted read-only (overlay)
├─ p6 swap      swap   PARTLABEL=swap        1 GiB
└─ p7 storage   ext4   PARTLABEL=storage     created on first boot (up to 85% of the disk)
```

The shipped image contains p1-p6 (a 10 GiB layout holding about 2.7 GB
of data): slot A holds the system, slot B is formatted but empty until
the first update (the menu shows it as "Empty", and it is never tried).
Flash it with `bmaptool` and the `.bmap` file next to it, which writes
only the blocks with data. On first boot `decksmithos-init-storage`
relocates the backup GPT to the end of the disk, creates p7 and formats
it. It refuses to run on a non-GPT disk or if p1-p6 do not carry the
expected PARTLABELs, and never formats a partition that already contains
a filesystem. The one exception is a p7 it has just created itself:
signatures found there are left-overs of the disk's previous use (the
areas bmaptool does not write keep their old contents) and are wiped.

---

## Slot Selection (tryboot A/B)

A slot is a boot partition plus its root filesystem: **A = p2 + p4**,
**B = p3 + p5**. Each slot has its own kernel, firmware, `config.txt`
and `cmdline.txt` (`root=PARTUUID=` of its own rootfs), and its own
`/etc/fstab` mounting its own boot partition on `/boot/firmware`. A slot
is therefore always updated as a whole.

The Raspberry Pi bootloader reads `autoboot.txt` from p1:

```text
[all]
tryboot_a_b=1
boot_partition=2      # default slot (A)
[tryboot]
boot_partition=3      # used for one boot after `reboot "0 tryboot"`
```

The tryboot flag lasts for exactly one boot. Any later reboot or power
cycle returns to the default slot, which is the rollback path.

`decksmithos-slot` (on the device, as root):

| Command | Effect |
|---|---|
| `decksmithos-slot` | running slot, default slot, tryboot slot, bootloader flags |
| `decksmithos-slot try` | point `[tryboot]` at the other slot and reboot once into it |
| `decksmithos-slot commit` | make the running slot the default |
| `decksmithos-slot info` | per slot: running/default/tryboot and its version record |

Each boot partition carries `decksmithos-version.txt` (source revision,
build date, profile, display, Mixxx version; also `/etc/decksmithos/version`
in the rootfs). The system menu (short press on the power button) shows
both slots and offers "Restart into slot X" (try) and, in a tryboot
slot, "Keep slot X as default" (commit).

Updates only ever write the inactive slot, and only while the running
slot is the default: writing the default slot from an uncommitted
tryboot slot would destroy the fallback.

Update flow (updater not implemented yet): write boot + rootfs of the
inactive slot, `decksmithos-slot try`, check health in the new slot,
then `decksmithos-slot commit`. Without the commit the next reboot
returns to the old slot.

`autoboot.txt` is rewritten by writing a new file and renaming it over
the old one. The bootloader reads it on every boot. Losing p1 makes the
disk unbootable, so nothing else writes to p1.

---

## Boot Partitions

Filesystem: FAT32, 512 MiB per slot (the Raspberry Pi OS trixie bootfs
size; holds kernels and initramfs for both 2712 and generic arm64).

Contents:
- firmware and kernel
- device tree files and overlays
- `config.txt` and `cmdline.txt` of the slot

---

## Root Filesystems (A/B)

DecksmithOS uses two root filesystem partitions to enable safe, firmware-style updates.

Partitions:

- `rootfs_A` (active or inactive depending on current boot target)
- `rootfs_B` (the other slot)

Filesystem: ext4, 4 GiB per slot.

Contents:
- operating system
- DecksmithOS runtime
- Mixxx installation

Mount options prioritize reliability over performance.

### Read-only at runtime

The running slot is never written. `overlayroot` (initramfs) mounts the
slot's rootfs read-only under `/media/root-ro` and puts a tmpfs overlay
on `/`: programs can still write, but those changes live in RAM and are
gone after a reboot. Persistent data belongs on `/storage` (Mixxx
settings and database, logs via the `/var/log` bind mount, dev SSH host
keys). `/boot/firmware` is mounted read-only as well.

The overlay is switched on by
`overlayroot=tmpfs:swap=1,recurse=0` in the slot's `cmdline.txt`
(`recurse=0` leaves `/storage` alone, `swap=1` keeps the swap partition).
`/etc/machine-id` is empty, so systemd uses a transient machine ID.

`decksmithos-rootfs` (on the device, as root):

| Command | Effect |
|---|---|
| `decksmithos-rootfs` | is the overlay active now / configured for the next boot |
| `decksmithos-rootfs rw` | next boot of this slot is writable (overlay off) |
| `decksmithos-rootfs ro` | next boot of this slot is read-only again |
| `overlayroot-chroot` | shell in the real rootfs mounted writable, no reboot needed |

These are meant for the dev profile; the release image has no login.

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
