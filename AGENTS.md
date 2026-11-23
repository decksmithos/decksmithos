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
    Implemented: no display manager. `decksmithos-session.service`
    runs `xinit /etc/X11/Xsession` as `dj` with `PAMName=login` on
    tty7 (a full logind session: seat0, x11, XDG_RUNTIME_DIR, user
    D-Bus); `Xorg.wrap` (xserver-xorg-legacy, `allowed_users=console`)
    starts the server. systemd restarts it when Mixxx exits ("Restart
    Mixxx", skin change); its `ExecStop` lets Mixxx save first. It
    replaced nodm (2026-11-20), which restarted its session on SIGTERM so
    every shutdown waited for the stop timeout. Units must not depend on
    `nodm.service` by name (x11vnc did and pulled nodm in next to it);
    use `display-manager.service`. The X server has no authority file:
    it admits the session user (`xhost si:localuser:dj` in Xsession), so
    X clients started by root run as `dj` (`runuser`). Openbox runs in
    the session.
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

Implemented (2026-11-22, to be measured): CPUs 0-2 for every service and
the session (systemd `CPUAffinity=0-2`, kernel `irqaffinity=0-2`), CPU 3
for Mixxx's audio thread only (it moves itself there, Mixxx patch 0018,
`DECKSMITHOS_AUDIO_CPUS=3`); `LimitRTPRIO=90`, `LimitMEMLOCK=infinity`,
`LimitNICE=-10` on `decksmithos-session.service` so that PortAudio's
SCHED_FIFO request succeeds (before: "Failed bumping priority", audio thread
SCHED_OTHER); governor `performance` (tmpfiles.d); track analysis and library
scan at nice 10 (`DECKSMITHOS_BACKGROUND_NICE`).

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
`boot_partition` under `[all]`; `systemctl reboot
--reboot-argument="0 tryboot"` boots the
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
-   Runtime root is read-only (implemented, both profiles; verified on
    the CM5 2026-11-20): no initramfs; the kernel mounts the slot
    read-only and `decksmithos-overlay-init` (`init=` in each slot's
    `cmdline.txt`, written by `build/postprocess.sh`) puts a tmpfs
    overlay on top (ext4 at `/media/root-ro`, tmpfs at `/media/root-rw`),
    comments the root out of the overlay's fstab and execs systemd; on
    any failure it boots the plain root instead. It replaced Debian's
    `overlayroot` in an initramfs, which cost ~1.3 s (40 ms now). Do not
    add `auto_initramfs=1` (the first image lacked it, so overlayroot
    never ran; with it, the initramfs would run before our init).
    Everything outside `/storage` is lost at reboot. `/boot/firmware` is
    mounted `ro`.
    `/etc/machine-id` is empty (transient ID, no "first boot" on every
    boot). Tools must find the root device from `root=PARTUUID=` in
    `/proc/cmdline`, because `/` is an overlay. Dev: `decksmithos-rootfs
    rw|ro` toggles the overlay for the next boot of the running slot,
    `decksmithos-rootfs chroot` changes the real root (restart afterwards:
    an overlay's lower layer changed underneath is not guaranteed to show
    through, and the ext4 often stays busy/writable until then); dev SSH
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

Clock: the CM5 RTC (battery on the IO board) is read by the kernel at
boot and written back every 11 minutes while NTP is synchronized
(verified 2026-11-20, including a power cut of a few minutes: correct
time before NTP). `decksmithos-clock` saves the time to
`/storage/state/clock` at shutdown and every 15 minutes; at boot the RTC
wins when it is at or after the saved time, and only an RTC that lost
the time is replaced by the saved time (both profiles).

Time zone (implemented, verified on the CM5 2026-11-20): the image stays
on `TIMEZONE_DEFAULT` (UTC); the choice is saved in
`/storage/config/system/timezone` and `decksmithos-timezone.service`
(after `storage.mount`, before sysinit and the session, ~25 ms) writes
`/etc/localtime` and `/etc/timezone` into the overlay at every boot.
Set it from the system menu ("Time zone": region, then city, 16 per page)
or `decksmithos-timezone set Europe/Bucharest` (root; the menu goes
through `decksmithos-system timezone-set`). Only zones from `zone.tab`,
`UTC` and `Etc/UTC` are accepted (not paths, regions or tzdata's own
files such as `posixrules`). The RTC, the saved clock and the journal stay
in UTC; Mixxx reads the zone when it starts. `timedatectl set-timezone`
writes only the overlay and is lost at restart.

Machine ID: the image's `/etc/machine-id` is empty (read-only root);
`decksmithos-overlay-init` writes a stable one into the overlay, derived
from the board serial (md5 of `decksmithos-machine-id:<serial>`; it
mounts sysfs briefly, since `/proc/device-tree` points into `/sys`).
Without it systemd invented a random ID at every boot and journald,
which files the persistent journal per machine ID, started a new
directory each time (`journalctl -b -1` found nothing). Dev runs
`systemd-timesyncd`; release has no network. RTC battery charging
(`dtparam=rtc_bbat_vchg=...`) is off and must stay off on the
development board: it has a CR2032 (not rechargeable; user, 2026-11-20).
Enable charging only on a board with a rechargeable cell (e.g. the
official ML-2020 Li-Mn).

The journal is persistent (`journald.conf.d/50-decksmithos.conf`,
both profiles) in `/storage/logs/journal` through the `/var/log` bind
mount. A freshly flashed full image also brings demo tracks
(`build/demo-music/`, CC0/CC BY/CC BY-SA, credits in `CREDITS.txt`),
copied once to `/storage/library/Demo/<Genre>/` when `/storage` is
created, with one Mixxx crate per genre; update files never carry them.

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
-   Debconf preseeds live in `stage-decksmithos/00-install-packages/00-debconf`
    (now `xserver-xorg-legacy/allowed_users`; formerly nodm's start
    prompt, which hung a build waiting on whiptail);
    `DEBIAN_FRONTEND=noninteractive` is exported from `build/config*`.
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
    The rule matches any block device with a USB ancestor
    (`SUBSYSTEMS=="usb"`), not `ID_BUS=="usb"`: NVMe/SATA enclosures
    with a SAT bridge report `ID_BUS=ata` (found on the user's NVMe
    enclosure, which then was not mounted).
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
real mouse shows it while moving). **No long-press right click**
(decided 2026-11-22): the evdev `EmulateThirdButton` emulation was
removed from the td2 profile because it delivered a touch to Mixxx only
on finger movement or release, which made held on-screen buttons
(momentary effects, cue preview) impossible. Controllers do not send
right clicks either, so the skins must not depend on right click
(context menus and knob reset stay mouse-only). Finger scrolling of the
library lists: Mixxx patch 0012 (`DECKSMITHOS_TOUCH_SCROLL`, set by
`decksmithos-mixxx`), unverified on the panel. The browse tree shows only
CONSOLE (`/storage/library`), USB and USB2, the USB entries only while a
drive is mounted (patch 0013, `DECKSMITHOS_BROWSE_SOURCES`). The search
box and every other text field show an on-screen keyboard while focused
(patch 0014, `DECKSMITHOS_TOUCH_KEYBOARD`; Mixxx has none on Linux). The
sidebar sections can be ordered, hidden and renamed (Preferences > Library >
Sidebar, patch 0015); `decksmithos-mixxx-autoconf` sets the order Playlists,
Auto DJ, History, Crates, Recordings, Tracks, Rekordbox, Serato, Analyze and
hides the folder tree (Sources; decided 2026-11-22: Tracks and SEARCH cover
all drives, and two DJs' drives at once are avoided at events) and iTunes.
The top bar (PLAYLIST, BROWSE, AUTO DJ, SEARCH, MENU) opens sections
with `[Library],show_<key>` through the skin bridge; the button of the
section shown is lit, a second tap closes the library page, a tap on
another button switches to its section; BROWSE always opens Tracks (all music)
and stays lit in Crates, History, ... opened from the sidebar (Playlists and
Auto DJ have their own buttons; fixed 2026-11-23: it used to reopen the last
section, lighting that section's button); no BACK button (removed 2026-11-22: with touch lists and
second-tap close it had no use left); SEARCH
searches Tracks (all music). EJECT buttons for /usb and /usb2 in the library
bar (patch 0017, `decksmithos-system eject`: unmount and detach; refused
while a track from the drive plays). rekordbox/Serato drives are imported
transparently (patch 0016, decided 2026-11-22): rekordbox playlists and
Serato crates (crates as playlists, to keep their order; subcrates as
"Parent ▸ Child") become locked playlists "USB ▸ ..." at the top of
Playlists while the drive is in, the rekordbox analysis is applied to the
library tracks (rekordbox always wins, like a CDJ), a track loaded before
the background import gets it at load; the Rekordbox / Serato sections are
hidden. Not yet: the DJ's own edits kept on the drive in `DECKSMITHOS/`
(read-write mount only for drives with that folder), unverified with real
drives. Auto DJ
requests: patch 0010 (`[Library],AutoDjAddRequest`, REQUEST button in the
library), one console button learned from the skin's MENU page (0011).
Remaining touch work: small
buttons outside the top bar (BEAT FX channel buttons, Q), verification on
the real panel. None of these skins fits 480×320.

Screen-size adaptation (implemented, verified on the CM5 2026-11-20):
`decksmithos-mixxx-autoconf` (run by `decksmithos-mixxx` before Mixxx
starts) takes the screen's physical size from xrandr/EDID (HDMI) or,
when the output reports 0 mm (the DSI Touch Display 2 does), from
`DISPLAY_DIAGONAL_INCH` in `/etc/decksmithos/display.conf` (display
profile), and sets `[Library] RowHeight` to ~6 mm (50 px on the 7"
panel, Mixxx default 20) and `[Preferences] geometry` to the screen.
Values the user changed in Mixxx's preferences are left alone (last
automatic values in `decksmithos-auto.json`). Picking a skin by screen
size is not done yet (only the 7" skins exist).

Skin and settings: the system menu has "Mixxx settings" (focuses Mixxx
and sends Ctrl+P via XTEST; works with the hidden menu bar) and "Skin"
(installed skins minus the "(64 Samplers)" variants, those larger than
the screen disabled). `decksmithos-mixxx-ui set-skin` leaves the choice
in `decksmithos-pending-skin` and stops Mixxx; the autoconf applies it
before the next start, because Mixxx rewrites `mixxx.cfg` when it quits.
The patch series (2026-11-21, `build/mixxx/README.md`): `0000` the
upstream 2.5 branch since 2.5.6 (`make-stable-patch.sh`), `0001` ronso0's
`[Controls],show_preferences` (his commit from #13266, unchanged; the
"DecksmithOS Standalone" gear panel's MIXXX / SETTINGS button uses it;
`[App],show_preferences` of `~deb13decksmithos2`/`3` is gone), `0002`
auto-enable controllers, `0003` a "do not show again" option for the
"No Output Devices" warning (`[Soundcard] HideNoOutputWarning`, reset
when an output is configured in the preferences, as ronso0 suggested on
#13252; `decksmithos-mixxx-autoconf` sets it at every start, and while
it is set Mixxx does not write `soundconfig.xml` back), `0004`
`DECKSMITHOS_NO_SOUND_DIALOGS` for the busy/error dialogs only
(appliance-only), `0005` sound and controller hotplug, `0006` the Auto
DJ "Harmonic" ordering. Earlier: `0002-decksmithos-appliance-ui.patch`
was published as `2.5.6+dfsg-3~deb13decksmithos2` (2026-11-20) and
pinned; without a controller, Mixxx 2.5.6 stopped at a "No Output
Devices" dialog that an appliance cannot answer.
The sound and controller hotplug patch (now `0005`; published as
`~deb13decksmithos3`; verified on the CM5 2026-11-20 with the Mixtrack
Pro 3: Mixxx started without it in 1 s with no dialog; plugging it in
gave sound and an auto-enabled, opened controller ~5 s later; unplugging
closed the outputs (the device query blocks the GUI ~6 s); plugging it
in again restored both in 0.1 s; same Mixxx process throughout): with
`DECKSMITHOS_SOUND_HOTPLUG_HOOK` (set by `decksmithos-mixxx` to
`decksmithos-soundconfig`), Mixxx checks `/proc/asound/cards` every
second; on a change it runs the hook (writes `soundconfig.xml`, prints
`DECKSMITHOS_ALSA_CARD=<id>`, which Mixxx puts in its environment for
the ALSA PCM `decksmithos`), queries the sound devices again, sets them
up from `soundconfig.xml` and enumerates the controllers again
(PortMidi restarted). Not while the preferences are open. A start
without the output device no longer writes an empty `soundconfig.xml`
(now part of `0003`).
`decksmithos-mixxx` therefore waits only 1 s (was 20) for the
controller at start. `decksmithos-soundconfig` rewrites
`soundconfig.xml` when it is missing, unchanged since it wrote it, or
has no output (the old checksum test ran in the wrong directory and
always kept the file). A new Mixxx build means raising
`MIXXX_LOCAL_SUFFIX`, running the workflow with publish and
`pin-release.sh`, committed together (the image build refuses a version
that `release.sha256` does not pin).

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
    touchscreen, Show/Hide touches, Time zone; dev only: Restart writable / Restart
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
(AB EEPROM or `flashrom`); never downgrades. `rpi-eeprom-update` stages
its files in `BOOTFS`, so it runs with `BOOTFS` in `/run` (the first
hardware try failed on the read-only `/boot/firmware`); success only on
"UPDATE SUCCESSFUL". Verified on the CM5 IO board (2026-11-20): flashrom
path (Winbond W25Q16), 2025-12-08 -> 2026-10-30. The same write applies
the DecksmithOS EEPROM settings (`/etc/decksmithos/bootloader.conf`:
NVMe first, no UART log, no net-install or HDMI diagnostics screen); the
menu offers "Apply bootloader settings" when only those differ. Boot
time measurements: `docs/boot-time.md`.

Touch tools (`decksmithos-touch`): `calibrate` runs `xinput_calibrator`
and stores the evdev axis calibration in
`/storage/config/touch/evdev-axis-calibration`, applied by `.xsession`;
`overlay on|off` (remembered in `/storage/config/touch/overlay`; `overlay
session` at session start restores it, default on in dev, off in release;
"Show/Hide touches" in the system menu, both profiles) starts `xcompmgr`
plus `decksmithos-touch-overlay`
(click-through ARGB window: fading discs for taps, trails for drags,
growing disc while held, orange on right click; reads X RECORD for the
mouse and the touch device itself (BTN_TOUCH, ABS_X/Y mapped like
xf86-input-evdev), because Mixxx/Qt takes touches as XInput2 touch
events, which X RECORD does not show as pointer events). The touch
device name in `touch.conf` is a substring: kernel 6.18 reports
"10-005d Goodix Capacitive TouchScreen". The overlay refuses to start without a
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
    e.g. `logo.image.Rotate(-1.5708)` (−π/2 radians; +π/2 for the
    opposite mounting, see §15).
-   Boot to Mixxx without text or black gaps (2026-11-20, verified on
    the CM5): both profiles boot `quiet splash vt.global_cursor_default=0
    logo.nologo`; Plymouth starts with systemd (no initramfs) at ~1 s.
    `decksmithos-session.service` conflicts with `plymouth-quit.service`,
    runs `plymouth deactivate` and starts X on **tty1** (the Plymouth VT;
    `chvt 7` hung, and another VT loses the image), so `getty@tty1` is
    masked and the dev root console is on tty2. Plymouth's image did not
    survive X's start (tried `-background none`, glamor, rotated DSI), so
    `decksmithos-x-splash` (first in `.xsession`) shows the same
    `splash.png` logo band as the X root background (`hsetroot -full
    /usr/share/decksmithos/splash-band.png`, first command in
    `.xsession`); Mixxx starts over it (and it shows while Mixxx
    restarts). Plymouth quits (`--retain-splash`) just before X starts
    (`ExecStartPre`; with only `deactivate` it drew its text-mode
    progress). X runs with `-nocursor`: the hardware cursor plane showed a
    few stray squares at every X start (touch appliance; a USB mouse has
    no pointer either). `decksmithos-splash-done` is a fallback quit once
    Mixxx's window is viewable. Both show the logo band of the 768x1024 canvas
    (full width, 420 px around the centre) scaled proportionally to the
    screen width (5/3 on the 7" panel), so the logo keeps its size from
    Plymouth to X.
    The dev compositor and notice start only after Mixxx is up (the
    compositor would paint over the splash).
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
eth0 DHCP runs in the background (`decksmithos-dhcp.service`, dhcpcd,
dev only; no ifupdown `auto eth0`, which held `network.target` and with
it the X session and Mixxx until a lease arrived); the address is shown in the dev
notice and the system menu. The release image has no eth0
configuration. Dev mode exists only in the dev image (decided): every session starts
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
    First run (2026-11-20, CM5 IO board, Samsung MZVL2256HCHQ-00BH1
    256 GB): link 8.0 GT/s x1; 4 x 8 GiB direct write/read on `/storage`
    plus 8 GiB raw read in ~95 s: 766 MB/s write, 872 MB/s read, steady
    across rounds; no AER/NVMe kernel messages; NVMe 36 -> 50 °C (still
    rising), SoC 55 °C. Still to do: a longer run to thermal steady state
    and a run with Mixxx playing.
-   [ ] A/B slots identified correctly (`decksmithos-slot` shows A).
-   [x] `decksmithos-slot try` boots slot B once; `commit` in B makes B
    the default (verified 2026-11-20 after fixing the reboot call:
    systemd 257 rejects `systemctl reboot "0 tryboot"`, use
    `--reboot-argument=`). Update from the USB menu into B: 29 s.
    Still to check: a plain reboot from an uncommitted B returns to A.
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

Status legend: **Open** = nobody decided yet; **Measure** = decided
direction, needs a measurement on the hardware; **Decided** = done,
kept here for the reasoning. Update the status when something changes.

### Hardware

| # | Question | Status |
|---|---|---|
| 1 | Exact CM5 carrier, USB topology and power budget | Open (CM5 IO board in use) |
| 2 | NVMe model, capacity, thermals; PCIe Gen 3 (`pciex1_gen=3` is on) | Measure (§12) |
| 3 | Exact Waveshare 3.5" display, touch controller and overlay | Open |
| 4 | Final 7" display interface (DSI/HDMI) | Open (Touch Display 2 on DSI works, §15) |
| 16 | Primary display for development: 3.5" SPI or Touch Display 2 | Open |
| 11 | eMMC: unused, rescue system, or other | Open |

### OS, build and updates

| # | Question | Status |
|---|---|---|
| 5 | Raspberry Pi OS release and pinned pi-gen revision | Open |
| 7 | Display manager | **Decided (2026-11-20):** none; `decksmithos-session.service` (xinit, PAM login session) replaced nodm. Verified on the CM5: Mixxx, touch overlay, menu, VNC, Restart Mixxx, shutdown 0.7 s with a clean session stop |
| 8 | Plymouth on the SPI panel | Open |
| 9 | A/B boot and rollback | **Decided:** tryboot (§5); signed `decksmithos.update` from USB (`docs/update-strategy.md`). Still open: automatic health check before keeping a slot |
| 10 | Partition sizes and the 15% reserve | Open (rootfs 4 GiB per slot now) |
| 12 | Package management in the final image | Release removes apt (§6); dev keeps it |
| 13 | Standard vs. low-latency/RT kernel | Measure (xruns, latency) |
| 15 | A second DecksmithOS-owned Git repository | Open (none so far) |

### Mixxx and user interface

| # | Question | Status |
|---|---|---|
| 6, 18 | Mixxx version and skin schema; fate of the TinyDeck 480 draft | Mixxx pinned at 2.5.6 (§7); TinyDeck 480 open |
| 17 | Touch input on the 7" display | **Decided:** yes (§7) |

### Product, licensing

| # | Question | Status |
|---|---|---|
| 14 | Source license and trademark/logo policy | Open (needs legal advice, §10) |
| 19 | Bluetooth speakers as audio output | **Decided: no** (2026-11-19), see below |

**Why no Bluetooth speakers (#19).** A2DP adds about 150--250 ms of
variable latency (aptX LL is rare on speakers and poorly supported on
Linux), so the master on the speakers lags the headphone cue and
beatmatching by ear breaks; compensating with Mixxx's headphone delay
makes jog/cue/scratch feel late. Speakers on Bluetooth plus headphones
on the controller's USB audio means two clocks drifting apart (xruns or
desync). It would bring back BlueZ, a pairing UI and a radio in release
(Bluetooth is disabled on purpose, §4), and 2.4 GHz is unreliable in
crowded venues. For practice at home, put an external Bluetooth
transmitter on the controller's master output. Revisit only if a
measured low-latency path exists.

### Feature gaps vs. club and standalone gear

From the comparison with CDJ-3000/3000X, XDJ-RX3, XDJ-AZ, OPUS-QUAD,
Denon Prime 4 G2, SC6000, Rane System One and others
(`docs/feature-comparison.md`, research of 2026-11-20). Much of what
the flagships do is already in Mixxx 2.5 (keylock, sync, quantize, key
sync/shift, hot cues and saved loops, slip, loops, beat jump, effects,
samplers, recording, on-device analysis, reading rekordbox USB exports);
these are not yet tested on DecksmithOS. The gaps:

| # | Feature (who has it) | DecksmithOS now | Status / proposal |
|---|---|---|---|
| 20 | Touch library browsing: big rows, finger scroll, BPM/key filter buttons, playlist editing on the unit (all flagships) | Mixxx library, small rows; search filters by typing | Open -- likely the most visible gap on the 7" screen |
| 21 | Playback survives pulling the USB stick: whole track in RAM (CDJ-3000/X) | Unknown; Mixxx reads in chunks | Measure first (checklist §8), then decide |
| 22 | rekordbox USB sticks as the main workflow: playlists, cues, grids (all AlphaTheta) | Mixxx's Rekordbox library feature (`/media/usb*` links exist) | Measure with the user's sticks; key for Pioneer users |
| 23 | Phrase display (rekordbox PHRASE) and a touch beatgrid editor (Engine) | Mixxx patch 0007 (2026-11-22): rekordbox phrases as a band in the overview, downbeats and bar.beat counter, imported with the Rekordbox view; no own phrase analysis | Phrases: test with a real rekordbox USB. Upstream PRs #16581/#16582/#16491 target main's renderer and were not ported (see build/mixxx/README.md). Beatgrid editor: open |
| 24 | Stems: on-device separation (Prime 4 G2, System One) or stem files (Engine) | No | Open; on-device separation only with measured CPU headroom (no xruns) |
| 25 | Smart Cue / Gate Cue cue modes (CDJ-3000X, XDJ-RX3/AZ) | Hot cue preview exists in Mixxx; no Smart Cue | Open; must stay controller-agnostic |
| 26 | Streaming and cloud libraries: Beatport, TIDAL, Apple Music, Dropbox (most 2023+ units) | No | Proposal: no for release (no network by design); revisit only with an offline-cache design |
| 27 | Link between units: Pro DJ Link / StageLinQ, shared library, sync | No | Open; probably out of scope |
| 28 | Lighting: DMX, Hue, SoundSwitch, phrase-aware lights (Prime 4 G2, CDJ-3000/X) | No | Proposal: out of scope for now |
| 29 | Boot time and power-loss behaviour (no flagship publishes them) | Unmeasured; read-only root and A/B slots | Measure and publish: could become a DecksmithOS strength |
| 30 | Zone output, 10-band room EQ, multiple mic inputs (all-in-ones) | Depends on the controller's audio interface | Open; controller-agnostic, so only via what Mixxx supports |
| 31 | Automatic mixing from a prepared playlist ("AI mode"; Engine DJ/rekordbox have smart playlists and auto-mix features) | Mixxx Auto DJ: plays a crate/playlist with fixed-length crossfades or intro/outro cues; no key/BPM ordering, no phrase-aligned transitions | **Decided (2026-11-20), staged:** (1) Auto DJ set up for DecksmithOS and started from the menu (sync/quantize, transition mode); (2) queue ordering by key compatibility (Camelot) and tempo, from Mixxx's own analysis: **in progress (2026-11-21)** as `build/mixxx/patches/0006-decksmithos-autodj-harmonic-order.patch` ("Harmonic" button and `[AutoDJ],sort_harmonic`; tracks keep their key, unlike upstream draft PR #17519); (3) a transition engine as a JS mapping on a virtual MIDI device, no Mixxx patch: **first version (2026-11-21)** `mixxx/controllers/DecksmithOS-AutoDJ.js` on snd-virmidi card 7 ("VirMIDI 7-0", enabled by `decksmithos-mixxx-autoconf`): tempo and phase match within 8 %, keylock, EQ bass swap at the crossfader middle, slow return to the track's own tempo afterwards (upstream: daschuer on #9821, #11956). **Transition catalogue (2026-11-22)**: blend, filter, echo, reverb, cut, loop roll, riser, brake/backspin, chosen per transition by SMART (tempo match within 8 %, Camelot key distance, weights, no repeat, brake at most 1 in 8) or RANDOM, each switchable on the MENU page (`[Skin],dsm_adj_*`); lengths in beats and phrase-aligned starts through Mixxx patch 0021 (`[AutoDJ],next_transition_beats`, `phrase_align`, `seconds_to_transition`, `fade_now` honouring the beats); echo/reverb on effect unit 4 ("DecksmithOS AUTO DJ FX", set by `decksmithos-mixxx-autoconf`; Mixxx channel effects are post-fader, so tails survive the fader). Phrases from rekordbox, else detected (patch 0020, from upstream PRs #16582 and #17404). Queue and sources by touch (2026-11-22, patch 0022 + skin): a second library row with AUTO DJ, FADE NOW, SKIP, HARMONIC, + RANDOM, AUTO FILL in the Auto DJ section, + QUEUE / + NEXT / + ALL elsewhere and SOURCE for a crate; playlists = ordered sets (+ ALL), crates = Auto DJ sources for AUTO FILL; the top-bar AUTO DJ has a green outline while Auto DJ runs. PLAY on the waiting deck (any controller) is FADE NOW while Auto DJ runs (2026-11-23; not tied to PFL: the waiting deck has the headphone cue on during Auto DJ). Judged by listening on the hardware. Upstream has no ordering or beat-matched transitions (researched 2026-11-21; the unlicensed beatItAutoDJ script is reference only). No cloud or on-device LLM: release has no network, and a local model would compete with audio for CPU |

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

The panel is mounted with the glass's narrow margin on the left (the
enclosure in `hardware/enclosure` needs this so that the display cables
reach J5 and the GPIO header). The values below are for that orientation.
The opposite mounting (narrow margin on the right) was verified on the
device with `rotate=270`, Xorg `right`, touch `SwapAxes` + `InvertY` and
Plymouth +π/2; the current values are that set turned by 180 degrees and
must be validated again on the device (checklist below).

1.  **Kernel console/framebuffer** --- appended to the existing single
    line in `cmdline.txt` (do not replace existing arguments):

    ``` text
    video=DSI-1:720x1280@60,rotate=90
    ```

    (`rotate=270` for the opposite mounting, verified on the device.)

2.  **Xorg output** --- `/etc/X11/xorg.conf.d/90-display-rotate.conf`,
    a `Monitor` section for `DSI-1` with `Option "Rotate" "left"`.
3.  **Touch input** --- `/etc/X11/xorg.conf.d/91-touch-rotate.conf`,
    an `InputClass` matching the Goodix touch controller with
    `Option "SwapAxes" "1"` and `Option "InvertX" "1"`. These are
    evdev options (the touch device uses the evdev driver via
    `45-evdev.conf`).
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
