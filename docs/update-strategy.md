# Update Strategy

DecksmithOS is updated like firmware: a new system is written as a whole
into the slot that is not running, booted once, and kept only if it works.
The running slot, `/storage` and `autoboot.txt` are never touched by an
update.

---

## Initial Installation

The first installation writes the disk image from another computer,
preferably with `bmaptool copy` (only the blocks with data are written;
`dd`, Raspberry Pi Imager or balenaEtcher also work, writing all 10 GiB):

```text
build/output/decksmithos-<profile>.img
build/output/decksmithos-<profile>.bmap
```

It holds the partition table, slot A, an empty slot B and swap. The
first update fills slot B. `/storage` is created on first boot. See
`first-boot-checklist.md`.

---

## System Updates (A/B slots)

### The update file

`build/make-update.sh <image>` turns a built image into a signed update
file, `build/output/decksmithos-<profile>-<version>.update`. It is an
uncompressed tar holding:

| Member | Content |
|---|---|
| `manifest` | `format`, `version`, `date`, `profile`, `display`, `mixxx`, `bootloader`, SHA256 of both archives, rootfs size |
| `manifest.sig` | `ssh-keygen -Y sign` signature over the manifest (namespace `decksmithos-update`) |
| `boot.tar.zst` | boot partition contents |
| `rootfs.tar.zst` | root filesystem (numeric owners, xattrs, ACLs) |

The manifest is signed, and it carries the archives' hashes, so the
signature covers everything. The device trusts only the key in
`/etc/decksmithos/update-signers` (from
`build/stage-decksmithos/04-system-menu/files/update-signers`). The
private key (`~/.ssh/decksmithos_ed25519`, passphrase protected) stays
on the build machine and never enters the repository; keep an offline
backup. Losing it means devices accept no more menu updates until they
are reflashed (or a last update signed with it installs a new key).

Archives are tar files rather than partition images, so updates keep
working if the slot sizes change, and the slot is formatted fresh on
every install.

### Installing

From the system menu (short press on the power button), release and dev:

1. Copy the update file to the root of a USB stick as
   **`decksmithos.update`** (fixed name, any letter case).
2. Insert the stick and open the menu. The update button shows the
   version and profile, "older" or "same build" where that applies, or
   "invalid signature" (disabled). Without a file it reads
   "No update on USB" (disabled).
3. Tap twice: the menu shows progress while the update is installed into
   the inactive slot. Then "Restart into slot X" boots it once.
4. In the new slot, "Keep slot X as default" commits it. Without that,
   any restart returns to the previous slot.

In the dev profile, the same is available as
`sudo decksmithos-update [check|install] <file>` (e.g. after `scp`).

### What the installer does (`decksmithos-update`)

1. Verifies the manifest signature and the format.
2. Refuses unless the running slot is the default. While a slot runs
   once through tryboot, the default slot is its fallback and must not
   be overwritten: keep the running slot or restart into the default
   first.
3. Verifies both archives against the manifest before writing anything.
4. Formats the inactive slot's boot (FAT32) and root (ext4) partitions
   and extracts the archives.
5. Rewrites the slot's `cmdline.txt` and `fstab` with this disk's
   PARTUUIDs (the update carries the build image's).
6. Writes the slot's `decksmithos-version.txt` last. A slot without it
   (interrupted install) is shown as "Empty or incomplete" and
   `decksmithos-slot try` refuses to boot it.

Allowed: older versions (rolling back a regression), the same build, and
switching between dev and release. `/storage` is shared by both slots,
so Mixxx settings, the library database and the touch calibration stay.

---

## Bootloader (EEPROM) Updates

The board's bootloader lives in the CM5's SPI flash, outside the A/B
slots. Each DecksmithOS version carries the `rpi-eeprom` package with
the bootloader release it was built and tested with. The menu shows the
installed bootloader date and offers "Update bootloader" only when the
included one is newer; it never downgrades. It asks for two taps, warns
not to power off, and uses only the immediate update path of
`rpi-eeprom-update` on BCM2712 (A/B EEPROM partitions if the running
bootloader supports them, otherwise `flashrom`). `/boot/firmware` stays
read-only, so the old `recovery.bin` method cannot start half-way. The
new bootloader is used from the next restart.

A failed EEPROM write is not covered by the system's A/B slots; recovery
then needs `rpiboot` from another computer. Do not update it without a
reason (see `first-boot-checklist.md`, section 0, for the minimum needed
by this disk layout).

---

## Update Safety

- `/storage` is never formatted or written by an update.
- The running slot is read-only (overlay) and never written.
- Every update is signed and hash-checked before anything is written.
- A new slot boots once; it becomes the default only when kept.
