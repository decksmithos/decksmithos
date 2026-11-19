# Flashing DecksmithOS

The first installation writes a complete disk image to the NVMe SSD of
the CM5. Everything on that SSD is erased. Later versions are installed
from the system menu with an update file and need no flashing
(`update-strategy.md`).

## Files

| File | Use |
|---|---|
| `decksmithos-release.img.xz` | compressed image for distribution (Raspberry Pi Imager, balenaEtcher, bmaptool) |
| `decksmithos-release.img.xz.sha256` | checksum of the compressed image |
| `decksmithos-<profile>.img` + `.bmap` | uncompressed image and block map (development, `bmaptool`) |
| `decksmithos-<profile>-<version>.update` | signed update for the system menu (not for flashing) |

The image describes a 10 GiB layout (both system slots and swap), but
only about 2.7 GB of it holds data: slot B stays empty until the first
update. That is why the compressed image is much smaller than 10 GiB.

## Getting the NVMe to the computer

Either way, the SSD shows up as a disk on the computer:

1. **USB adapter:** take the NVMe out and put it in an M.2 NVMe to USB
   adapter.
2. **On the CM5 IO board, without removing anything:** put the board in
   USB boot mode (see the Raspberry Pi documentation for the CM5 IO
   board: disable eMMC boot / nRPIBOOT), connect its USB-C port to the
   computer and run `rpiboot` with the mass-storage gadget
   (`rpiboot -d mass-storage-gadget64`). The NVMe then appears as a USB
   drive. On Windows, install `rpiboot` with Raspberry Pi's installer.
   *Not yet tried with the DecksmithOS board.*

## Windows and macOS

**Raspberry Pi Imager** (recommended):

1. Choose Device: *Raspberry Pi 5* or *No filtering*. This only filters
   Imager's own OS list; a custom image is written as it is.
2. Choose OS: *Use Custom*, select `decksmithos-release.img.xz`.
3. Choose Storage: the NVMe (check the size, so that you do not pick
   another disk).
4. If asked about OS customisation (user, Wi-Fi, SSH): choose **No**.
   DecksmithOS configures itself; Imager's settings would not apply.
5. Write. Imager decompresses the image on the fly and verifies what it
   wrote.

**balenaEtcher** works the same way: *Flash from file*, select the
`.img.xz`, select the NVMe, *Flash*.

Both write the whole 10 GiB layout, which takes a few minutes on a
USB 3 adapter.

## Linux

`bmaptool` (package `bmap-tools`) writes only the blocks that hold data
and checks them against the block map:

```sh
lsblk                                         # find the NVMe, e.g. /dev/sdX
sudo bmaptool copy decksmithos-release.img.xz /dev/sdX
# or, from a build tree: (uses decksmithos-dev.bmap next to the image)
sudo bmaptool copy build/output/decksmithos-dev.img /dev/sdX
```

Raspberry Pi Imager, balenaEtcher and
`xz -dc decksmithos-release.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress`
work as well. Check the download first:
`sha256sum -c decksmithos-release.img.xz.sha256`.

With `bmaptool`, the areas it skips keep the SSD's old contents. That is
harmless: slot B and swap are formatted, and the first boot wipes stale
signatures in the new `/storage` partition.

## Before the first boot

The CM5's bootloader (EEPROM) must be recent enough to boot GPT from
NVMe and to understand the A/B slots (`tryboot_a_b`). Check it with the
steps in `first-boot-checklist.md`, section 0. The first boot creates
`/storage` and restarts once by itself.
