# First Boot Checklist (CM5)

Manual steps for bringing up a freshly built image on the target
hardware. Nothing here has been verified on a CM5 yet; record what
passes in `AGENTS.md` section 12. Use the **dev** image
(`build/output/decksmithos-dev.img`): it has SSH, VNC and a root console.

Dev access: user `dj` / `root`, password `decksmithos`, SSH key from
`build/stage-decksmithos-dev/00-configure-dev-runtime/files/authorized_keys`,
VNC on port 5900 (password `decksmit`). The device gets its address by
DHCP on eth0.

---

## 0. Before flashing: bootloader EEPROM

The layout needs a bootloader that boots GPT from NVMe and understands
`tryboot_a_b` in `autoboot.txt`. Check it from whatever system still
boots on the board (or via `rpiboot` on the carrier):

```sh
vcgencmd bootloader_version          # date of the running bootloader
sudo rpi-eeprom-update               # compares with the newest packaged release
sudo rpi-eeprom-config | grep -E 'BOOT_ORDER|PCIE_PROBE'
```

- [ ] Bootloader is recent (update with `sudo rpi-eeprom-update -a` and
      reboot if `rpi-eeprom-update` reports a newer version).
- [ ] `BOOT_ORDER` contains `6` (NVMe), e.g. `0xf416` or `0xf461`.

DecksmithOS does not update the EEPROM by itself
(`rpi-eeprom-update.service` is disabled, `/boot/firmware` is read-only).
To update it later from the dev image: `sudo decksmithos-rootfs rw`,
reboot, `sudo mount -o remount,rw /boot/firmware`,
`sudo rpi-eeprom-update -a`, reboot, `sudo decksmithos-rootfs ro`, reboot.

## 1. Flash

Windows/macOS (Raspberry Pi Imager, balenaEtcher) and flashing through
the CM5 IO board's USB port with `rpiboot`: see `flashing.md`.

Write the image to the NVMe (everything on it is lost), e.g. with the
NVMe in a USB adapter on the build host. `bmaptool` uses
`decksmithos-dev.bmap` next to the image and writes only the ~2.7 GB of
data instead of the whole 10 GiB layout:

```sh
lsblk                                   # identify the NVMe, e.g. /dev/sdX
sudo bmaptool copy build/output/decksmithos-dev.img /dev/sdX
# without bmap-tools (writes all 10 GiB):
# sudo dd if=build/output/decksmithos-dev.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The areas bmaptool skips keep the disk's old contents. That is harmless:
slot B and swap are formatted, and first boot wipes stale signatures in
the new `/storage` partition.

- [ ] `sudo sgdisk -p /dev/sdX` (or `sfdisk -l`) shows p1-p6 with names
      autoboot, boot_A, boot_B, rootfs_A, rootfs_B, swap.

## 2. First boot

The first boot creates `/storage` (p7) and reboots once by itself.

- [ ] Console text (dev; release shows the splash) in landscape, then
      Mixxx starts full screen.
- [ ] `lsblk -o NAME,SIZE,PARTLABEL,LABEL,MOUNTPOINTS` shows p7
      `storage` mounted on `/storage`; the end of the disk (about 15%)
      is unallocated.
- [ ] `journalctl -u decksmithos-storage-init` has no errors.
- [ ] `/storage/config/mixxx`, `/storage/logs` exist; `/var/log` is the
      bind mount of `/storage/logs` (`findmnt /var/log`).
- [ ] SSH works; after a reboot the host key is unchanged (kept in
      `/storage/dev/ssh-host-keys`).

## 3. Read-only root

```sh
findmnt /                      # FSTYPE overlay
sudo decksmithos-rootfs        # now: read-only, next boot: read-only
findmnt /boot/firmware         # options start with ro
```

- [ ] `sudo touch /etc/decksmithos-test`, reboot: the file is gone.
- [ ] `sudo decksmithos-rootfs rw`, reboot: `findmnt /` shows ext4 and
      `/etc/decksmithos-test` survives a reboot; remove it,
      `sudo decksmithos-rootfs ro`, reboot: overlay again.
- [ ] `sudo overlayroot-chroot` opens a shell in the real rootfs; exit
      leaves it read-only again.
- [ ] `swapon --show` lists the swap partition.

## 4. A/B slots

Slot B is empty after flashing: `decksmithos-slot try` refuses it and
the menu shows it as "Empty". Fill it first with the update file of the
same build (`build/output/decksmithos-dev-<version>.update`):

```sh
scp build/output/decksmithos-dev-*.update dj@<ip>:/storage/
sudo decksmithos-update install /storage/decksmithos-dev-*.update
```

(or copy it to a USB stick as `decksmithos.update` and use the menu).

```sh
sudo decksmithos-slot          # running A, default A, tryboot B
sudo decksmithos-slot try      # reboots once into B
sudo decksmithos-slot          # running B, default A; "tryboot flag 1"
sudo reboot                    # back to A (rollback path)
sudo decksmithos-slot try      # into B again
sudo decksmithos-slot commit   # B becomes the default
sudo reboot                    # stays in B
```

- [ ] Each step behaves as commented. Finish by making A the default
      again (`try` from B, then `commit` in A).
- [ ] In both slots `findmnt /storage` and Mixxx work (slot B has its
      own kernel and cmdline but the same system).
- [ ] Before the update: `sudo decksmithos-slot try` refuses the empty
      slot B without rebooting.

## 5. Display and touch (td2, Touch Display 2)

- [ ] Panel needs its separate 5 V supply; `dmesg | grep -i ili9881`
      shows no deferred probe.
- [ ] Console, Plymouth and X all in the same landscape orientation.
- [ ] Touch hits where the finger is, in all four corners
      (`xinput list` shows the Goodix device). If an axis is mirrored,
      adjust `SwapAxes`/`InvertX`/`InvertY` in
      `build/stage-decksmithos/03-display-profile/files/td2/xorg.conf.d/91-touch-rotate.conf`.
- [ ] Buttons, faders and library scrolling are usable by finger.
- [ ] No mouse cursor on screen; a USB mouse shows it while moving.
- [ ] Long press (about 1 s) opens the context menu in the library
      (right click). A short tap still acts immediately on release.

## 6. Controller: Numark Mixtrack Pro 3

```sh
amidi -l                       # MIDI port, e.g. "Mixtrack Pro 3 MIDI 1"
cat /proc/asound/cards         # its USB audio card
less /storage/logs/mixxx/mixxx.log
```

- [ ] Mixxx enables the mapping "Numark Mixtrack (Pro) 3" without
      visiting the preferences (log line from the auto-enable patch;
      needs the DecksmithOS Mixxx 2.5.6 package, not Debian's 2.5.0).
- [ ] `decksmithos-mixxx` log reports the controller card with 4
      playback channels and writes `soundconfig.xml` with Main 1-2 and
      Headphones 3-4.
- [ ] Master out and headphone cue both work; deck buttons, jog wheels,
      pitch faders and LEDs respond.
- [ ] Unplug/replug the controller while Mixxx runs; note what happens.
- [ ] Start Mixxx without the controller, plug it in later; note what
      happens.

## 7. Power button and system menu

- [ ] `journalctl -u decksmithos-powerd` shows
      `listening on /dev/input/eventN`.
- [ ] Measure the PMIC's forced power-off: hold the button and count
      the seconds until the board cuts power (do this from a state where
      a hard power cut does no harm). `LONG_PRESS_SECONDS` in
      `/etc/default/decksmithos-power` (default 2) must stay well below it.
- [ ] Short press opens the menu over Mixxx; a second short press closes
      it; it closes by itself after a minute.
- [ ] Power off / Restart need two taps; Mixxx settings changed just
      before are still there after the restart (Mixxx saved on SIGTERM).
- [ ] Long press powers off cleanly (`journalctl -b -1` after the next
      boot ends with a normal shutdown).
- [ ] Slot panel shows version, date and Mixxx version for A and B;
      "Restart into slot B" boots B once; "Keep slot B as default" there
      works; "Restart into slot A" from an uncommitted B goes back to A.
- [ ] Dev: "DEVELOPMENT MODE" notice appears after Mixxx starts; touches
      are shown as fading discs; "Restart writable" / "Restart read-only"
      switch the root filesystem.
- [ ] Calibrate touchscreen: the result survives a reboot
      (`/storage/config/touch/evdev-axis-calibration`).
- [ ] System update from USB: `build/make-update.sh` on the laptop,
      copy the `.update` file to a stick as `decksmithos.update`. The
      menu shows its version; install it (progress bar), "Restart into
      slot B" boots it, "Keep slot B as default" there; restarting
      without keeping returns to A. Note how long the install takes.
- [ ] An update file with a changed byte in `manifest` shows "invalid
      signature"; pulling the stick during an install leaves slot B
      "Empty or incomplete" and slot A untouched.
- [ ] Bootloader button shows the installed date; if it offers an
      update, note which path `rpi-eeprom-update` uses (AB or flashrom)
      in the result text.

## 8. USB storage

- [ ] First stick mounts read-only on `/usb`, second on `/usb2`
      (`findmnt /usb /usb2`); tracks appear in the library.
- [ ] Removing a stick while no track from it plays leaves Mixxx running.

## 9. Load and endurance

- [ ] One hour of playback with both decks: no xruns in the Mixxx log,
      `vcgencmd get_throttled` is `0x0`, temperature noted
      (`vcgencmd measure_temp`).
- [ ] `free -h` after the hour: overlay (RAM) use stays small.
- [ ] Power cut during playback, then boot: system comes up, `/storage`
      clean (`journalctl -b | grep -i fsck`).
