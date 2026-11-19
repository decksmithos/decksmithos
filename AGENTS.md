# AGENTS.md --- DecksmithOS

Project guide for contributors and coding agents. This document
consolidates design discussions; it distinguishes decisions from
proposals and does not assert that every feature is already implemented.
Inspect the repository before changing code.

## 1. Identity and purpose

-   Product name and capitalization: **DecksmithOS**.
-   Main repository discussed:
    https://github.com/decksmithos/decksmithos
-   Purpose: an appliance-style Linux DJ system based on Raspberry Pi
    Compute Module hardware and Mixxx.
-   Keep the project controller-agnostic. The initial Numark controller
    is already supported by Mixxx and is recognized without a
    DecksmithOS-specific driver or mapping. Do not add model-specific
    assumptions.
-   Default language for source, documentation, comments,
    function/procedure names, logs, and commit messages: English.
-   Make focused changes; do not regenerate unrelated files.

## 2. Git repositories and ownership

### Main repository

The DecksmithOS GitHub repository is the project-owned source of truth.
It should contain build orchestration, DecksmithOS pi-gen stages,
overlays, service definitions, documentation, Mixxx skin source/assets,
and validation/release scripts.

### pi-gen checkout

The agreed approach is to clone the official Raspberry Pi `pi-gen`
repository locally under `build/pi-gen` and synchronize
DecksmithOS-specific stages/configuration into it during builds.

`build/pi-gen` is an upstream working checkout/cache, not a
DecksmithOS-owned source tree. Do not commit its full contents, `work/`,
`deploy/`, generated images, or build caches to the DecksmithOS
repository. Keep custom stages in the DecksmithOS repository. Pin or
record the upstream pi-gen revision for reproducibility.

No second DecksmithOS-owned Git repository was identified in the
discussions. If another repository is introduced, document its purpose,
ownership, remote, and update policy.

## 3. Hardware direction

-   Early development used Raspberry Pi 4; Raspberry Pi 5 was
    considered.
-   Current intended direction: Raspberry Pi Compute Module 5 (CM5),
    with an M.2/NVMe-capable carrier.
-   CM5 options discussed:
    -   CM5004064: 4 GB RAM / 64 GB eMMC / 465 lei.
    -   CM5008016: 8 GB RAM / 16 GB eMMC / 595 lei.
    -   CM5008064: 8 GB RAM / 64 GB eMMC / 640 lei.
-   Working recommendation: prefer 8 GB RAM. The 8 GB / 16 GB eMMC model
    looked like the best value if NVMe is the primary storage. The 8 GB
    / 64 GB option is also viable if eMMC is useful for recovery or
    other purposes. Prices are historical user-provided quotes, not
    current market data.
-   NVMe is intended for the system and persistent music data. Do not
    hardcode throughput claims; benchmark the actual SSD, carrier, PCIe
    link, and thermal behavior.
-   Initial display concept: Waveshare 3.5-inch SPI touchscreen,
    480×320. Later targets: approximately 5-inch and official 7-inch
    Raspberry Pi display.
-   **Verified on hardware (see §15):** CM5 with the official Raspberry
    Pi Touch Display 2 (7-inch, DSI, 720×1280 native portrait, Goodix
    touch) works under Xorg. Whether the 3.5-inch SPI panel or the
    Touch Display 2 is the primary development target must be stated
    explicitly in the repository; do not assume.
-   HDMI, DSI, and SPI display support should be considered, but exact
    Waveshare controller/touch models and overlays must be identified.
    Do not assume all Waveshare 3.5-inch displays are interchangeable.
-   Initial USB topology concept: one USB port for the DJ controller and
    the other three for USB sticks or additional controllers. Validate
    actual carrier topology and power budget; do not assume every CM5
    carrier exposes four suitable independent ports.

## 4. OS and runtime

### Base system

-   Raspberry Pi OS Lite 64-bit, built with official pi-gen.
-   Appliance-oriented minimal runtime, not a general desktop
    distribution.
-   Mixxx starts automatically in a dedicated X session.
-   Prefer Xorg and a minimal session over a full desktop environment.
    `nodm` was preferred for autologin; verify availability/behavior on
    the selected OS release. Openbox was considered but is not a
    requirement unless needed.
-   Avoid adding Wayland or a heavyweight desktop without a concrete
    technical reason.

### Users and security

-   Primary Linux user: `dj`, not `pi`.
-   pi-gen requires `FIRST_USER_PASS` to avoid first-boot user rename
    behavior. For release builds, generate a unique high-entropy
    credential or use a documented provisioning flow. Never use a
    predictable shared production password.
-   A dev image was discussed with wired LAN, DHCP, SSH, and `dj`
    password `decksmithos`. This is development-only and must never leak
    into release. Verify whether it is implemented.
-   Development image should allow root-level debugging access through a
    documented mechanism.
-   Release image should keep direct root login locked unless a secure
    maintenance design is deliberately adopted.
-   Earlier root-account/config issues were traced to final pi-gen
    export-stage selection: custom final stages lacked `EXPORT_IMAGE`.
    Ensure the selected final dev/release stage has the marker file and
    validate the exported image itself.

### Networking and unused hardware

Release intent: - disable Wi-Fi; - disable Bluetooth; - disable camera
support; - disable integrated Raspberry Pi audio. The development
profile may enable wired Ethernet with DHCP and SSH. Keep this
separation explicit. Do not remove packages just because they appear
network-related. Check dependencies and preserve boot, udev, Xorg, USB,
display, audio, and Mixxx functionality.

### Audio architecture

-   Use the DJ controller's own USB audio interface.
-   Master output is taken from the controller's RCA outputs;
    booth/headphone output from its jack, as applicable to the supported
    controller.
-   Do not route audio through Raspberry Pi onboard audio.
-   JACK or PipeWire is not automatically required. Use the Mixxx audio
    backend supported by the chosen version and controller. Add
    JACK/PipeWire only for a demonstrated feature or compatibility
    requirement.
-   The integrated Pi audio device is not needed for the intended setup.

### Real-time performance

A real-time/low-latency kernel was considered, but it is not a guarantee
of low latency. Measure xruns/dropouts, buffer stability, CPU load,
thermal throttling, USB behavior, and latency on target hardware.
Compare standard and low-latency/RT kernels. Do not claim sub-5 ms
performance without measurement.

## 5. Disk layout and firmware updates

Decided layout: **GPT** (target is CM5 only; Pi 3 and older cannot
boot GPT). Implemented in `build/postprocess.sh` and
`decksmithos-init-storage`:

``` text
NVMe (GPT)          PARTLABEL   FS LABEL
├── p1 autoboot     autoboot    AUTOBOOT   FAT16, 32 MiB, autoboot.txt only
├── p2 boot_A       boot_A      BOOT_A     FAT32, 512 MiB, boot files of slot A
├── p3 boot_B       boot_B      BOOT_B     FAT32, 512 MiB, boot files of slot B
├── p4 rootfs_A     rootfs_A    rootfs_A   ext4, 4 GiB
├── p5 rootfs_B     rootfs_B    rootfs_B   ext4, 4 GiB
├── p6 swap         swap        swap       1 GiB
└── p7 storage      storage     storage    ext4, created on first boot
```

Look partitions up by PARTLABEL/LABEL, not by number, where possible
(fstab and cmdline use PARTUUIDs so that a USB disk with the same labels
cannot be picked). The image is smaller than the disk, so first boot
must relocate the backup GPT to the end of the disk
(`sfdisk --relocate gpt-bak-std`) before creating p7.

Decided boot selection: **Raspberry Pi bootloader tryboot A/B**
(`autoboot.txt` with `tryboot_a_b=1`). Slot A = p2 + p4, slot B = p3 +
p5; each slot has its own kernel, `config.txt` and `cmdline.txt`, and its
fstab mounts its own boot partition on `/boot/firmware`. Default slot is
`boot_partition` under `[all]`; `reboot "0 tryboot"` boots the
`[tryboot]` partition exactly once, so a failing new slot falls back on
the next reboot/power cycle. `decksmithos-slot` (status / try / commit)
implements this on the device; see `docs/disk-layout.md`. Unverified on
CM5 hardware until the checklist item passes.

### Boot

-   FAT32 boot partition.
-   Size must be based on actual firmware/kernel/config requirements,
    not an old assumed 32 MB value.
-   Recent Raspberry Pi OS releases commonly use `/boot/firmware`;
    verify paths for the pinned release.
-   Preserve required boot arguments and firmware settings when applying
    custom configuration.

### A/B root filesystems

-   `rootfsA` and `rootfsB` are separate system slots.
-   Runtime root is read-only (implemented, both profiles): `overlayroot`
    in the initramfs (`overlayroot=tmpfs:swap=1,recurse=0` in each
    slot's `cmdline.txt`, written by `build/postprocess.sh`) mounts the
    slot read-only with a tmpfs overlay; everything outside `/storage`
    is lost at reboot. `/boot/firmware` is mounted `ro`.
    `/etc/machine-id` is empty (transient ID, no "first boot" on every
    boot). Tools must find the root device from `root=PARTUUID=` in
    `/proc/cmdline`, because `/` is an overlay. Dev: `decksmithos-rootfs
    rw|ro` toggles the overlay for the next boot of the running slot,
    `overlayroot-chroot` makes one-off changes without rebooting; dev SSH
    host keys persist in `/storage/dev/ssh-host-keys`.
-   Firmware update writes the inactive slot, validates it, then
    switches boot selection.
-   Provide rollback if the new slot fails.
-   Do not perform routine `apt upgrade` on the running system.
-   A few GB per rootfs was the target; 2--3 GB was discussed as a
    possible optimized size, not a measured result. Keep each under 10
    GB if practical, but validate the full dependency set. Current
    slot size: 4 GiB (`ROOTFS_SIZE_MIB`); the dev rootfs used 2.5 GB
    with Mixxx 2.5.0, too close to the former 3 GiB.

### Persistent storage

Initial structure:

``` text
/storage/
├── config/
├── library/
└── logs/
```

Possible additions, only if needed by real components:

``` text
/storage/updates/
/storage/backups/
/storage/state/
```

Implemented: Mixxx runs with `--settings-path /storage/config/mixxx/`
(database, analysis, cues, settings); defaults ship read-only in
`/usr/share/decksmithos/mixxx-defaults/` and are copied only when
missing. Its session log goes to `/storage/logs/mixxx/`. Mixxx must not
write tags or Serato markers into audio files
(`SyncTrackMetadataExport 0`, `SeratoMetadataExport 0`).

Use ext4. Consider periodic `fstrim` where supported; do not assume
continuous `discard` is always preferable. Ensure ownership and
permissions are explicit, with user data accessible to `dj`.

### First-boot partition creation

The image contains autoboot, slot A, an empty (formatted) slot B and
swap; the first update fills slot B. `postprocess.sh` also writes a
`.bmap` next to the image, so `bmaptool copy` flashes only the ~2.7 GB
of data instead of the 10 GiB layout. First boot creates `/storage` (p7)
from remaining disk space. The implemented initializer refuses to run
unless the disk is GPT and p1--p6 carry the expected PARTLABELs, and
never formats a partition that already holds a filesystem, except stale
signatures on a p7 it created itself in the same run (bmaptool leaves a
used disk's old contents in the unwritten areas). A reserve of approximately 15% of total disk
capacity was discussed to avoid allocating all available SSD space; this
is a project proposal, not a universal SSD rule.

The initializer must be idempotent, validate the intended disk and
existing partition table, never overwrite existing user data, handle
interruption safely, create the filesystem, discover UUIDs, configure
mounting, and log its actions. Do not use "partition 4 missing" as the
only safety check.

## 6. pi-gen implementation rules

Custom stages discussed:

``` text
build/stage-decksmithos/
build/stage-decksmithos-dev/
build/stage-decksmithos-release/
```

A prior layout included:

``` text
stage-decksmithos/
├── 00-install-packages/
├── 01-configure-base-runtime/
└── 02-install-session-files/

stage-decksmithos-dev/
└── 00-configure-dev-runtime/

stage-decksmithos-release/
└── 00-configure-base-runtime/
```

Check the current repository and `STAGE_LIST`; names/order may have
changed.

### Host versus target rootfs

A serious previous bug occurred because stage scripts ran destructive
commands on the build host instead of inside the target rootfs.

-   Use `on_chroot <<'EOF' ... EOF` for commands intended to run inside
    the target.
-   Use `${ROOTFS_DIR}/...` for host-side file operations targeting the
    image.
-   Never run unqualified destructive commands (`rm`, `systemctl`,
    `useradd`, `apt`, etc.) if the target rootfs is intended.
-   Validate paths and quote variables.
-   Follow pi-gen step conventions (`00-run.sh`, package list files,
    stage `prerun.sh`) for the pinned revision.

### Package management and debconf

-   Use noninteractive package installation.
-   Preseed package-specific debconf choices, rather than blindly
    suppressing prompts.
-   `nodm` prompts whether it should start at boot (this hung a build
    waiting on whiptail): preseeded in
    `stage-decksmithos/00-install-packages/00-debconf`
    (`nodm/enabled true`); `DEBIAN_FRONTEND=noninteractive` is exported
    from `build/config*`.
-   Separate base, dev-only, and removal package lists.
-   Do not remove apt/package tools before all pi-gen package
    installation and cleanup steps are complete. Removing package
    management from the final immutable image is a possible late-stage
    decision, not an early build-stage action.
    pi-gen's `export-image` itself runs `apt-get` (userconf-pi,
    dist-upgrade), so the release profile removes apt in
    `build/postprocess.sh` after export, not in its stage.
-   A release purge also removes reverse dependencies: purging `netbase`
    takes `python3`, `openbox` and `rpi-eeprom` with it. The release
    stage checks that required packages survived and fails otherwise.

### Export and boot configuration

-   The final active stage for each profile must contain `EXPORT_IMAGE`;
    otherwise pi-gen can export an earlier stage and omit later
    modifications.
-   Ensure `stage-decksmithos-dev/EXPORT_IMAGE` and
    `stage-decksmithos-release/EXPORT_IMAGE` exist when those are the
    final selected stages.
-   Verify final image contents, not merely stage logs.
-   A previous issue involved `/boot/firmware/config.txt` being
    overwritten during export. Apply final boot configuration at the
    correct stage and inspect the exported image.
-   Do not replace the entire `config.txt` with a minimal file without
    preserving settings required by the target OS, firmware, display,
    and board.
-   Apply Wi-Fi/Bluetooth/audio overlays/settings in a way verified for
    the exact board and Raspberry Pi OS release.

## 7. Mixxx integration

### General

-   Mixxx is the DJ application and launches automatically.
-   Initial Numark controller is already supported by Mixxx; do not add
    a model-specific driver or mapping.
-   Pin the Mixxx version and validate all skin XML against that exact
    version. Pinning mechanism: `build/mixxx/` rebuilds a Debian Mixxx
    source package (currently `2.5.6+dfsg-3` from sid) for trixie arm64
    via `.github/workflows/mixxx-deb.yml`, with the DecksmithOS patches
    in `build/mixxx/patches/`. Do not install sid binaries into the
    image (they require sid's glibc, Qt and FFmpeg) and do not base the
    image on sid. The image installs the GitHub release pinned by
    SHA256 in `build/mixxx/release.sha256` (`pin-release.sh`) and holds
    the packages; `DECKSMITHOS_MIXXX=debian` (trixie 2.5.0) is for build
    tests only.
-   First start must go straight to the Mixxx interface (no dialogs).
    Implemented in `decksmithos-mixxx` + defaults: library root dirs
    `/usb`, `/usb2`, `/storage/library` pre-seeded in `mixxxdb.sqlite`
    (Mixxx's schema uses `CREATE TABLE IF NOT EXISTS`; verified against
    all 39 revisions of 2.5.6); `soundconfig.xml` generated for the ALSA
    PCM `decksmithos` (`/etc/asound.conf`, first USB playback card, Main
    1-2, Headphones 3-4 if present); `show_menubar_hint 0`,
    `[Direct Rendering] Warned yes`; HDMI audio off (`noaudio`).
    `/media/usb{,2}` symlinks exist because Mixxx's Rekordbox feature
    only scans `/media/*`. Unverified on hardware: PortAudio listing the
    `decksmithos` PCM, and controller auto-enable (Mixxx 2.5 enables a
    controller only with `[Controller]` + `[ControllerPreset]` entries).
-   Do not assume an undocumented "Pro" or hidden Mixxx build exists.
    Use an official supported build unless a legitimate alternative is
    established.

### USB and audio

-   Initial design uses controller USB plus up to three additional USB
    sticks/controllers, subject to actual carrier topology and power.
-   USB storage (decided): at most **2** devices, mounted **read-only**
    at `/usb` and `/usb2` in order of insertion (a freed slot is reused;
    a third device is ignored and logged). One slot per physical device
    (first mountable partition). The system disk is never mounted.
    Not by label/UUID: Mixxx keys tracks by path, so a collection copied
    to another stick keeps its cues when it lands in the same slot.
    Implemented by `99-decksmithos-usb-storage.rules` →
    `decksmithos-usb-mount@.service` → `decksmithos-usb-mount`.
    Supported: vfat, exfat, ext2/3/4 (`noload`), hfsplus, ntfs (ntfs3).
    With two sticks present at boot, which one gets `/usb` is not
    deterministic.
-   Controller's USB audio interface and physical outputs are used
    directly.
-   No Pi onboard audio routing.
-   Do not add JACK/PipeWire without a concrete requirement.

### 3.5-inch 480×320 skin

Confirmed UI direction: - informational display only; - no on-screen
buttons or transport controls; - no hotcue buttons; - no browser
controls; - all control is performed using the physical controller; -
show both decks simultaneously.

A single-deck-focus design was rejected because it hides the other
deck's waveform and makes visual beatmatching/synchronization harder.

Required visual elements: - two compact horizontal waveforms, one per
deck; - RGB waveform rendering; - beatgrid markers; - clear
playhead/central play-position marker; - loop markers.

A small status area (e.g. deck, BPM, key, remaining time) may be
considered, but must not compromise legibility or the two waveforms.
Exact dimensions and fields are not finalized.

Mixxx skins are not arbitrary HTML/CSS. Start from a working skin
shipped with the pinned Mixxx version and use its valid skin
format/widget definitions. A Mixxx skin is a directory containing
`skin.xml` (whose `<manifest>` block carries metadata) plus optional
QSS stylesheets and image assets; there is no separate `manifest.xml`.
Confirm this against the skins bundled with the pinned version. Do not
ship placeholder XML as a production skin.

#### Draft skin "TinyDeck 480" (unvalidated)

A draft skin named **TinyDeck 480** was generated in a design
discussion (`skin.xml`, `style.qss`, `README.md`, targeting "Mixxx
2.3+"). Status: **never loaded in Mixxx and never tested on target
hardware.** Check whether it is in the repository before relying on it.

Draft design decisions, which may be reused if they survive validation:

-   Vertical budget of exactly 320 px: per deck 22 px status bar + 28 px
    overview strip + 105 px main waveform; 10 px divider between decks.
-   Status bar fields per deck: `DECK | BPM | KEY | REMAIN`.
-   Widgets used: `<Visual>` (main RGB waveform), `<Overview>`,
    `<NumberDisplay>` (BPM, remaining time), `<KeySpinBox>` (key).
    `KeySpinBox` is an interactive widget; prefer a read-only key
    display if the pinned version offers one, consistent with the "no
    on-screen controls" rule.
-   Deck accent colors: Deck 1 cyan `#00e5ff`, Deck 2 orange `#ff8800`.
    Waveform band colors: low `#ff3344`, mid `#44ff88`, high `#00bbff`
    (Deck 2 high `#ffaa00`). Note that the effective RGB waveform
    colors may be governed by Mixxx waveform settings rather than the
    skin; verify.
-   Beatgrid markers, loop markers, and the central playhead are drawn
    by the Mixxx waveform renderer; they should not need extra skin
    widgets, but their visibility/colors must still be verified on the
    pinned version.

Validation: 1. render at actual 480×320; 2. load and play both decks; 3.
confirm RGB, beatgrid, playhead, and loop markers; 4. verify no touch
controls are displayed; 5. measure CPU/GPU/rendering behavior on CM5; 6.
test long-duration playback and audio stability.

Do not claim GPU acceleration or performance improvement without
measurement.

### Skins for the 7-inch landscape display (1280×720)

Decided: default **DecksmithOS Standalone** (adapted from "XDJ OPEN
SOURCE" by Marc Monka); optional **DecksmithOS Compact** (adapted from
"Pioneered" by Sven Boekelder) and LateNight (ships with Mixxx, not
renamed). Third-party names and logos are removed from what the user sees;
author credit is kept in `skin.xml` and each `LICENSE` (GPL-3.0). Sources,
upstream revisions and the list of changes: `mixxx/skins/UPSTREAM.md`.
`build.sh` syncs `mixxx/skins/` into stage 02, which installs them into
`/usr/share/mixxx/skins/`.

**Touch is used on the 7-inch display** (decided; on-screen buttons are
allowed there, unlike the 3.5-inch skin). Page switching must stay
controller-agnostic: the library page follows the standard
`[Skin],show_maximized_library` control, never a skin-private control.
Implemented, unverified on the panel: the mouse cursor is hidden
(`unclutter-xfixes --start-hidden --hide-on-touch` in `.xsession`; a
real mouse shows it while moving), and a long press (800 ms) is a right
click (evdev `EmulateThirdButton`, td2 profile
`xorg.conf.d/92-touch-longpress.conf`). Trade-off: a touch reaches Mixxx
as a left click only on finger movement or release, so holding an
on-screen button (cue preview) is not possible by touch; delete the file
to turn it off. Remaining touch work: library row height and finger scrolling, small
buttons outside the top bar (BEAT FX channel buttons, Q), verification on
the real panel. None of these skins fits 480×320.

### Future display sizes

-   Medium (\~5-inch): envisioned as dual waveforms plus browser access.
-   Large (7-inch): envisioned as medium layout plus additional
    information. These are future directions, not finalized
    specifications.

### Power button and system menu

Implemented in `build/stage-decksmithos/04-system-menu/`, unverified on
hardware. The CM5 IO board's power button is a `gpio-keys` device named
`pwr_button` (GPIO 20, `KEY_POWER`, from the device tree). logind
ignores it (`logind.conf.d/decksmithos-power.conf`); its long-press time
is fixed at 5 s. `decksmithos-powerd` (root) handles it:

-   short press: `decksmithos-menu` over Mixxx (Tk, full screen, touch
    sized). Power off, Restart, Restart Mixxx (two taps each), Calibrate
    touchscreen, Show/Hide touches; dev only: Restart writable / Restart
    read-only. Slot panel: version, build date, profile and Mixxx version
    of A and B (`decksmithos-slot info`, read from
    `decksmithos-version.txt` in each boot partition); "Restart into slot
    X" = `decksmithos-slot try` (one boot, reboots now); in a tryboot slot
    "Keep slot X as default" = `commit`, and the default slot's button is
    a plain restart.
-   long press: clean power off after `LONG_PRESS_SECONDS`
    (`/etc/default/decksmithos-power`, default 2 s). Must be shorter
    than the PMIC's forced power-off hold time: measure on the hardware.
-   Root actions go through `decksmithos-system` (fixed action list,
    allowed for `dj` by `/etc/sudoers.d/decksmithos-system`). Power off and
    restart send Mixxx SIGTERM and wait up to 15 s; whether Mixxx saves
    its state on SIGTERM is unverified.

System updates (implemented, verified on a loop-device copy of the dev
image, not on hardware): `build/make-update.sh <image>` makes
`decksmithos-<profile>-<version>.update` (tar: `manifest`,
`manifest.sig`, `boot.tar.zst`, `rootfs.tar.zst`), signed with
`ssh-keygen -Y sign` (namespace `decksmithos-update`) by the key
`~/.ssh/decksmithos_ed25519` (passphrase in `~/.ssh/decksmithos.pass`;
never commit either). The device trusts
`/etc/decksmithos/update-signers`. The menu looks for
`decksmithos.update` (fixed name, any case) in the root of `/usb` or
`/usb2`; `decksmithos-update` installs into the inactive slot only while
the running slot is the default, verifies hashes before writing,
rewrites the slot's cmdline/fstab PARTUUIDs and writes
`decksmithos-version.txt` last (a slot without it is never tried).
Older versions and dev/release switches are allowed (decided). The
menu's "Update bootloader" (both profiles, decided) writes the
`rpi-eeprom` default release only if newer, via the immediate path
(AB EEPROM or `flashrom`); never downgrades.

Touch tools (`decksmithos-touch`): `calibrate` runs `xinput_calibrator`
and stores the evdev axis calibration in
`/storage/config/touch/evdev-axis-calibration`, applied by `.xsession`;
`overlay on|off` starts `xcompmgr` plus `decksmithos-touch-overlay`
(click-through ARGB window: fading discs for taps, trails for drags,
growing disc while held, orange on right click; reads X RECORD and the
touch device's BTN_TOUCH). The overlay refuses to start without a
compositor. The touch device name comes from
`/etc/decksmithos/touch.conf` (display profile).

## 8. Plymouth splash

A black-background DecksmithOS splash was requested, using a custom
Plymouth theme:

``` text
/usr/share/plymouth/themes/decksmithos/
├── decksmithos.plymouth
├── decksmithos.script
└── splash.png
```

Configuration discussed:

``` text
/etc/plymouth/plymouthd.conf
```

Use the actual DecksmithOS logo asset from the repository; do not invent
or substitute branding. Install required Plymouth packages and set the
theme as default using tools supported by the target OS release.

Kernel command-line options discussed:

``` text
splash quiet plymouth.ignore-serial-consoles vt.global_cursor_default=0
```

Preserve required existing root, filesystem, and console arguments; do
not replace the whole cmdline with only these flags. A black X
background can help the transition. Verify early-boot behavior on SPI
because the panel may become available later than HDMI/DSI.

Verified behavior (Touch Display 2, rotated, see §15):

-   The theme uses Plymouth's `script` module (`decksmithos.script`).
-   The `script` module **does not honor `DeviceRotation`** in
    `plymouthd.conf`. Rotation is applied inside the script instead,
    e.g. `logo.image.Rotate(1.5708)` (π/2 radians, 90°).
-   Rotation in the theme is therefore display-specific. If multiple
    displays/orientations are supported, parameterize it per display
    profile rather than hardcoding one angle for all images.

## 9. Dev and release profiles

### Development

Discussed intent: - wired LAN + DHCP; - SSH enabled; - `dj` account; -
known development password `decksmithos` was proposed; - root debugging
access; - optional diagnostic tools.

Implemented (dev profile only): password `decksmithos` for `dj` and
`root`; a trusted SSH public key
(`stage-decksmithos-dev/00-configure-dev-runtime/files/authorized_keys`)
for both `dj` and `root`; root autologin on tty1; `x11vnc` sharing the
running X display `:0` on port 5900 (`decksmithos-x11vnc.service`, VNC
password = first 8 characters of the dev password, i.e. `decksmit`).
Dev mode exists only in the dev image (decided): every session starts
the touch overlay with its compositor and shows an English
"DEVELOPMENT MODE" notice (`decksmithos-dev-banner`). Runtime tools read
the profile from `/etc/decksmithos/profile` (written by
`postprocess.sh`).

### Release

Discussed intent: - minimal package set; - Wi-Fi/Bluetooth/camera
disabled; - onboard audio disabled; - no unnecessary network services; -
read-only rootfs; - persistent logs/config/library under `/storage`; -
root interactive login locked; - no predictable shared credentials; -
Mixxx auto-start.

Keep profiles isolated and test the exported images independently. Do
not assume every item is already implemented.

## 10. Licensing and branding

No final license decision was made. The project owner expressed a
preference for non-commercial reuse (personal and educational use
permitted) and attribution to DecksmithOS name/logo for forks/reuse,
while preventing third parties from selling systems with DecksmithOS
preinstalled.

A standard permissive open-source license generally permits commercial
use; a non-commercial restriction generally means the project is not
OSI-approved open source. Trademark/name/logo policy is separate from
copyright licensing. Do not add a license or claim a decision has been
made without explicit approval. Consider separate policies for source
code, trademarks, logo artwork, and redistribution. Obtain legal advice
before publishing restrictive terms.

## 11. Suggested documentation

Suggested files (check existing tree before creating):

``` text
README.md
AGENTS.md
docs/
├── architecture.md
├── build.md
├── storage-layout.md
├── updates.md
├── hardware.md
├── displays.md
├── mixxx.md
├── development.md
└── release.md
```

Keep documentation synchronized with implementation.

## 12. Validation checklist

### Build/image

-   [ ] Raspberry Pi OS Lite 64-bit base.
-   [ ] pi-gen revision recorded/pinned.
-   [ ] Correct final stage has `EXPORT_IMAGE`.
-   [ ] Dev/release export from intended final stages.
-   [ ] No destructive stage command ran on host.
-   [ ] Final image located and inspected.
-   [ ] Boot config survives export.
-   [ ] `dj` user and credential policy correct.
-   [ ] Root policy matches profile.

### Boot/storage

-   [ ] Boots on target CM5 carrier.
-   [ ] Boot partition and firmware config correct.
-   [ ] PCIe Gen 3 (`dtparam=pciex1_gen=3`, unofficial on CM5)
    validated on the exact carrier + SSD: `lspci -vv` shows
    `LnkSta: Speed 8GT/s`; no AER/NVMe errors in `dmesg` after a
    sustained `fio` read/write run with the SSD at operating
    temperature. Record measured throughput; if any errors appear,
    remove the line and fall back to Gen 2.
-   [ ] A/B slots identified correctly (`decksmithos-slot` shows A).
-   [ ] `decksmithos-slot try` boots slot B once; next reboot returns
    to A; `try` + `commit` in B makes B the default.
-   [ ] Rootfs read-only in normal runtime (`findmnt /` shows
    `overlay`; `decksmithos-rootfs` status; a file written to `/etc`
    is gone after reboot; `rw`/`ro` toggle works in dev).
-   [ ] `/storage` mounted and writable.
-   [ ] First-boot partition creation safe/idempotent.
-   [ ] Existing data preserved.
-   [ ] Logs persist across reboot.

### Hardware/display/audio

-   [ ] Controller detected over USB.
-   [ ] USB sticks mount/eject safely.
-   [ ] Additional USB devices work within power budget.
-   [ ] 3.5-inch 480×320 display works.
-   [x] Touch Display 2 (DSI-1, 720×1280) works on CM5 --- manual
    bring-up only; re-verify from a built image.
-   [ ] Rotation consistent across cmdline, Xorg, touch, Plymouth.
-   [ ] Touch calibrated if used.
-   [ ] HDMI/DSI paths not broken by SPI-specific config.
-   [ ] Radio/camera/onboard-audio policy matches profile.
-   [ ] Controller USB audio selected.
-   [ ] Master/headphone outputs work from controller.
-   [ ] Both waveforms and all required markers render.
-   [ ] No on-screen controls in small skin.
-   [ ] Long playback has no xruns/dropouts.
-   [ ] CPU, temperature, memory, and rendering performance measured.

### Profile separation

-   [ ] Dev SSH/network settings do not leak into release.
-   [ ] Dev credentials do not leak into release.
-   [ ] Release has no unnecessary network services.
-   [ ] Root policy correct for each profile.
-   [ ] Both profiles tested independently.

## 13. Open decisions

Verify or decide explicitly: 1. Exact CM5 carrier and USB
topology/power. 2. NVMe model, capacity, thermals, and boot
configuration. 3. Exact Waveshare display and touch controller/overlay.
4. Final 7-inch display interface (DSI/HDMI). 5. Raspberry Pi OS release
and pinned pi-gen revision. 6. Mixxx version and skin schema. 7. `nodm`
suitability on selected OS. 8. Plymouth support on selected SPI panel.
9. ~~A/B boot selection and rollback mechanism~~ — decided: tryboot
(§5); updater implemented (`decksmithos-update`, signed
`decksmithos.update` from USB via the system menu, see
`docs/update-strategy.md`); automatic health check still open. 10. Partition sizes and
15% reserve policy. 11. Whether eMMC is unused, used for rescue, or
otherwise. 12. Whether package management is removed from final image.
13. Standard versus low-latency/RT kernel based on measurement. 14.
Final source license and trademark/logo policy. 15. Whether a second
DecksmithOS-owned Git repository is needed. 16. Primary display target
for current development (3.5-inch SPI vs Touch Display 2). 17. ~~Whether
touch input is used at all on the 7-inch display~~ — decided: yes (§7). 18. Pinned Mixxx version
and whether the TinyDeck 480 draft is kept, reworked, or discarded.
19. ~~Bluetooth speakers as audio output~~ — decided: no (2026-11-19).
A2DP adds about 150--250 ms of variable latency (low-latency codecs
such as aptX LL are rare on speakers and poorly supported on Linux), so
the master on the speakers lags the headphone cue on the controller and
beatmatching by ear breaks; compensating with Mixxx's headphone delay
makes jog/cue/scratch feel late. Main on Bluetooth plus headphones on the
controller's USB audio means two audio clocks drifting apart (xruns or
desync). It would also bring back BlueZ/bluez-alsa, a pairing UI and a
radio in release (Bluetooth is disabled on purpose, §4), and 2.4 GHz is
unreliable in crowded venues. For practice at home, use an external
Bluetooth transmitter on the controller's Master (RCA) output: no
system change. Revisit only if a measured low-latency path exists.

## 14. Instructions for coding agents

1.  Inspect the current repository and relevant files before editing.
2.  Treat repository code as the authority for implementation status;
    this document is design context.
3.  Put changes in the correct layer: build orchestration, pi-gen stage,
    rootfs overlay, runtime service, Mixxx skin, or docs.
4.  Keep host-side build actions separate from target-rootfs actions.
5.  Keep dev and release configuration isolated.
6.  Do not add controller-specific code.
7.  Do not add JACK/PipeWire, a full desktop, or extra network services
    without a demonstrated requirement.
8.  Do not add on-screen controls to the 3.5-inch skin.
9.  Preserve simultaneous visibility of both deck waveforms.
10. Do not claim performance improvements without measurements.
11. Update documentation and validation steps with implementation.
12. Explicitly report assumptions, unimplemented requirements, and
    destructive operations.
13. Never claim an image, archive, skin, build, or test exists or
    succeeded unless it was actually created or verified in the current
    environment.
14. Display configuration spans several layers (firmware overlay,
    kernel cmdline, Xorg output, Xorg input, Plymouth). When changing
    resolution or orientation, update every layer and the matching
    validation steps together; see §15.
15. Do not assume access to the target device. Commands meant for the
    device (`dmesg`, `i2cdetect`, `xrandr`, `xinput`) must be presented
    as steps for the human to run over SSH unless a device session is
    actually available.

## 15. Verified hardware notes (Touch Display 2 on CM5)

This section records configuration that was made to work on real
hardware during manual bring-up over SSH. It reflects a hand-configured
device, not necessarily what the pi-gen stages currently produce. Check
the repository and port these settings into the correct stage/overlay
if they are missing.

### Display: Raspberry Pi Touch Display 2 (7-inch, DSI)

-   Overlay in `config.txt`:

    ``` text
    dtoverlay=vc4-kms-dsi-ili9881-7inch,dsi0
    ```

-   DRM connector name is **`DSI-1`**, even though the overlay
    parameter is `dsi0`. Do not "fix" this asymmetry; use `DSI-1` in
    `video=` arguments and Xorg configuration. Re-verify the connector
    name after changing the carrier, port, or OS release.
-   Native mode: 720×1280@60 (portrait).

### Power / bring-up pitfall

-   The display showed nothing until its separate 5 V power cable to
    the GPIO header was connected. Without it, the display's I2C
    controller (address `0x45` on `i2c-10` in that setup) did not
    respond and the driver probe was deferred indefinitely in `dmesg`.
-   Lesson: when a display does not come up, check physical power and
    cabling and look for deferred-probe / I2C errors in `dmesg` before
    changing overlays or drivers.

### Rotation (landscape) --- four independent layers

Every layer must be configured separately; fixing one does not fix the
others.

1.  **Kernel console/framebuffer** --- appended to the existing single
    line in `cmdline.txt` (do not replace existing arguments):

    ``` text
    video=DSI-1:720x1280@60,rotate=270
    ```

    `rotate=270` is the value verified on the device (together with
    Xorg `right` and Plymouth +π/2 below); an earlier note said 90.

2.  **Xorg output** --- `/etc/X11/xorg.conf.d/90-display-rotate.conf`,
    a `Monitor` section for `DSI-1` with `Option "Rotate" "right"`.
3.  **Touch input** --- `/etc/X11/xorg.conf.d/91-touch-rotate.conf`,
    an `InputClass` matching the Goodix touch controller with
    `Option "SwapAxes" "1"` and `Option "InvertY" "1"`. These are
    evdev options (the touch device uses the evdev driver via
    `45-evdev.conf`); `92-touch-longpress.conf` relies on evdev too.
4.  **Plymouth** --- rotation inside `decksmithos.script` (see §8),
    because `DeviceRotation` is ignored by the `script` module.

Validation after any rotation change: boot console orientation,
Plymouth orientation, X/Mixxx orientation, and touch coordinates
(tap each corner) must all agree.

### Implications for the build

-   These files belong in the DecksmithOS repository (rootfs overlay or
    stage files), installed into `${ROOTFS_DIR}` by a pi-gen stage, not
    edited by hand on devices.
-   Display-specific settings (overlay, `video=`, Xorg rotate, touch
    matrix, Plymouth angle) are grouped per display profile under
    `build/stage-decksmithos/03-display-profile/files/<profile>/`
    (`config.txt` fragment, `cmdline.txt` fragment read by
    `postprocess.sh`, `xorg.conf.d/`, `plymouth/`). Select with
    `DECKSMITHOS_PRIMARY_DISPLAY` (default `td2`; `spi35` is
    unverified on CM5). Add new displays as new profiles.
-   The Mixxx skin for a 720×1280 panel used in landscape is a
    different layout target from the 480×320 skin; do not stretch the
    small skin.
