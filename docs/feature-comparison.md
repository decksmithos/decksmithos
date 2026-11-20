# Feature Comparison: DecksmithOS vs. Standalone DJ Gear

Research snapshot of 2026-11-20 (web research: manufacturer pages,
manuals, reviews). Values marked "(u)" are unverified, "n/s" means the
sources did not say. Section 1 compares DecksmithOS with the market;
sections 2 onwards are the raw inventory of the devices. Decisions that
follow from it are tracked in `AGENTS.md` section 13.

## 1. DecksmithOS today vs. the flagships

"Mixxx 2.5" means the feature exists in the pinned Mixxx release; it is
not yet tested on DecksmithOS hardware unless stated.

| Area | Flagships (CDJ-3000/X, XDJ-RX3/AZ, Prime 4 G2, ...) | DecksmithOS now |
|---|---|---|
| Library prep | rekordbox / Engine DJ export; Engine analyses on the device | On-device analysis (BPM, key, waveform, ReplayGain; Mixxx 2.5). Reads rekordbox USB exports, Serato and Traktor libraries (Mixxx 2.5) |
| Media | 1--4 USB, SD, SATA bay (Denon/Rane); FAT/exFAT/HFS+ | 2 USB slots (`/usb`, `/usb2`, read-only) + internal NVMe `/storage`; FAT, exFAT, ext2/3/4, HFS+, NTFS |
| Browse, search, filter | Touch browser, BPM/key/tag filters, history, playlist edit | Mixxx library: search with `bpm:`/`key:`/`genre:` filters, crates, playlists, history, Auto DJ; touch row height and scrolling still open |
| Keylock / sync / quantize | All | Mixxx 2.5 |
| Key sync / key shift | Most (not XDJ-RX3, XDJ-AN) | Mixxx 2.5 (sync key, pitch up/down) |
| Hot cues / saved loops | 8 per deck, memory cues, saved loops | Up to 36 hot cues per track, saved loops (Mixxx 2.5); how many are reachable depends on the controller and skin |
| Smart Cue / Gate Cue | CDJ-3000X (Gate Cue also XDJ-RX3/AZ) | Hot cue preview while held works in Mixxx; Smart Cue: no |
| Loops, beat jump, slip, reverse | All | Mixxx 2.5 (also loop roll, censor) |
| Tempo range | ±6% ... ±100% | Selectable up to ±90% (Mixxx 2.5) |
| Waveforms | 3-band / RGB, stacked decks | RGB and other types (Mixxx 2.5); both decks visible (skin rule) |
| Beatgrid editing | Basic (Pioneer), full editor (Engine) | Adjust/align/halve/double, no multi-tempo editor (Mixxx 2.5) |
| Phrase analysis | rekordbox PHRASE (display, lighting) | No |
| Stems | On-device separation on Prime 4 G2 / System One; none on AlphaTheta | No (Mixxx 2.5); stem files need a later Mixxx; on-device separation would need measured CPU headroom |
| Streaming / cloud | Beatport, TIDAL, Apple Music, Dropbox (Wi-Fi) | No (no network in release, by design) |
| Effects / sampler | 14--25 beat FX, Colour FX, some samplers | 4 effect units, many built-in effects, samplers (Mixxx 2.5) |
| Mic / recording | 1--2 mics; recording on most all-in-ones | Mic depends on the controller's audio interface; recording to `/storage/recordings` (configured) |
| Link between units | Pro DJ Link (6 players), StageLinQ | No |
| Lighting | DMX, Hue, SoundSwitch, Pro DJ Link Lighting | No |
| Full-track RAM cache (pulling USB keeps playing) | CDJ-3000/X | Not known; Mixxx reads tracks in chunks. To test (checklist section 8) |
| Internal library storage | Denon/Rane SATA bay | Yes: NVMe `/storage` |
| Firmware updates | USB / online, new features for years | Signed A/B updates from USB, rollback by tryboot; bootloader update in the menu |
| Robustness | Locking power cable; power-loss behaviour n/s | Read-only root, A/B slots, persistent journal; power-loss behaviour to test |
| Boot time | n/s | To measure |
| Wi-Fi / Bluetooth | Most 2023+ units | Disabled on purpose (release); Bluetooth speakers rejected (AGENTS.md §13) |
| Price | $1,200 (XDJ-AN) ... $2,999 (CDJ-3000X) | CM5 + carrier + NVMe + display + any Mixxx-supported controller |

### Gaps worth deciding (see AGENTS.md section 13, "Feature gaps")

1. Library on the touchscreen: row height, finger scrolling, BPM/key filter buttons, playlist/crate editing by touch.
2. Playback without the USB stick (full-track cache) or at least a safe failure.
3. rekordbox USB compatibility as the main workflow (Pioneer users bring rekordbox sticks).
4. Phrase display and a touch beatgrid editor.
5. Stems (files first; on-device separation only if the CM5 can do it without xruns).
6. Smart Cue / Gate Cue style cue modes (Mixxx mapping/skin work, controller-agnostic).
7. Lighting output (DMX/Hue) -- probably out of scope.
8. Streaming -- conflicts with the no-network release design.
9. Boot time and power-loss behaviour: measure and publish.

### CDJ-3000X

**Does a CDJ-3000X exist? Yes.** AlphaTheta announced it on 9 Sep 2025 and it shipped mid-Sep 2025. It is the first player sold under the AlphaTheta brand rather than Pioneer DJ. It is an iterative upgrade of the CDJ-3000, not a new platform. Compared with the CDJ-3000 it adds:

- a 10.1" touchscreen (up from 9") that shows 16 browse rows
- built-in Wi-Fi
- an NFC touchpoint for rekordbox Cloud login
- a Global Tag List that merges USB, cloud and streaming tracks, with background download
- playlist editing on the player
- Smart Cue and Gate Cue
- USB-C ports, an ESS DAC, a locking IEC power cable, and a wider jog-tension range

It drops the SD slot and still has no stems.

---

## 2. Devices covered

| Model | Maker | Released | Type | Source |
|---|---|---|---|---|
| CDJ-3000 | Pioneer DJ (AlphaTheta) | Sep 2020 | Media player | [pioneerdj.com](https://www.pioneerdj.com/en/product/player/cdj-3000/black/specs/) |
| CDJ-3000X | AlphaTheta | Sep 2025 | Media player | [alphatheta.com](https://alphatheta.com/en/product/dj-player/cdj-3000x/), [DJTT](https://djtechtools.com/2025/09/09/the-cdj-3000x-is-here-an-iterative-upgrade-of-the-media-player-for-3000-2399/) |
| SC6000 / SC6000M Prime | Denon DJ | 2019 | Media player (M = motorised platter) | [denondj.com](https://www.denondj.com/sc6000m-prime) |
| XDJ-XZ | Pioneer DJ | 2019 | 4-ch all-in-one (2 standalone decks) | [Crossfader](https://wearecrossfader.co.uk/blog/the-pioneer-dj-xdj-xz-full-review-and-guide/) |
| XDJ-RX3 | Pioneer DJ | Nov 2021 | 2-ch all-in-one | [pioneerdj.com](https://www.pioneerdj.com/en/product/all-in-one-system/xdj-rx3/black/overview/), [DDJT](https://www.digitaldjtips.com/?p=2769365) |
| OPUS-QUAD | Pioneer DJ | Mar 2023 | 4-ch all-in-one | [DDJT](https://www.digitaldjtips.com/reviews/pioneer-dj-opus-quad/) |
| XDJ-AZ | AlphaTheta | Oct 2024 | 4-ch all-in-one | [DDJT](https://www.digitaldjtips.com/reviews/alphatheta-xdj-az-standalone-dj-system/) |
| XDJ-AN | AlphaTheta | Jul 2026 | 2-ch all-in-one (entry, replaces XDJ-RR) | [alphatheta.com](https://alphatheta.com/en/information/xdj-an-an-all-in-one-dj-system/), [DDJT](https://www.digitaldjtips.com/reviews/alphatheta-xdj-an-all-in-one-dj-system/) |
| Prime 4+ | Denon DJ | Jun 2023 | 4-ch all-in-one | [Mixdown](https://mixdownmag.com.au/reviews/review-denon-dj-prime-4-dj-system/) |
| Prime 4 G2 | Denon DJ | Sep 2026 | 4-ch all-in-one (replaces Prime 4/4+) | [denondj.com](https://www.denondj.com/prime-4-g2), [DDJT](https://www.digitaldjtips.com/reviews/denon-dj-prime-4-gen-2/) |
| SC Live 4 | Denon DJ | Nov 2022 | 4-ch all-in-one, built-in speakers | [DDJT](https://www.digitaldjtips.com/reviews/denon-dj-sc-live-4-sc-live-2/) |
| Prime Go+ | Denon DJ | Oct 2024 | 2-ch battery-powered all-in-one | [DDJT news](https://www.digitaldjtips.com/denon-dj-prime-go-plus-news/) |
| System One | Rane (inMusic) | Jan 2026 | 2-ch all-in-one, motorised platters | [DDJT](https://www.digitaldjtips.com/reviews/rane-system-one-standalone/) |

Not covered in depth: OMNIS-DUO (AlphaTheta portable, 2024) and XDJ-1000MK2. One search found no SC6000 successor. DJTT reports that the SC6000 is no longer sold new in the US.

---

## 3. Feature tables

Legend: ✓ = yes, ✗ = no, n/s = sources did not say, (u) = unverified.

### 3a. Media players

| Feature | CDJ-3000 | CDJ-3000X | SC6000 / SC6000M |
|---|---|---|---|
| **Library and media** | | | |
| Media slots | 1 USB-A + 1 SD | 1 USB-A + 2 USB-C (storage/PC), no SD | 3 USB-A + SD + 2.5" SATA bay |
| Formats | MP3 AAC WAV AIFF FLAC ALAC | same | MP3 AAC WAV AIFF FLAC ALAC (u) |
| Filesystems | FAT16/32, exFAT, HFS+ (u, inferred from 3000X) | FAT16/32, exFAT, HFS+ (no NTFS) | FAT32, exFAT, HFS+ (u) |
| Library prep | rekordbox export, plus Cloud Analysis (BPM/grid/waveform from AlphaTheta DB) | rekordbox export / cloud | Engine DJ desktop export; **on-device analysis ✓** |
| Playlists / search / filter | ✓ / ✓ / Track Filter (BPM, key, My Tag…) | ✓ plus **playlist edit on device**, paste into search | ✓ / ✓ / ✓; playlist editing on device ✓ |
| Tag list / My Tag / history | ✓ / ✓ / ✓ | Global Tag List (USB + cloud + streaming) | Prepare list (u) / ✗ / ✓ |
| Related tracks | ✓ (u) | ✓ (u) | ✗ (u) |
| Streaming | Beatport (StreamingDirectPlay, fw 3.00); TIDAL n/s | Beatport, TIDAL, Apple Music (fw 1.31, Jan 2026) | Beatport, Beatsource, SoundCloud Go+, TIDAL (+Amazon via Engine, u) |
| Cloud library | rekordbox CloudDirectPlay (over LAN, paid plan) | CloudDirectPlay (Dropbox/Google Drive) over Wi-Fi; NFC login | Dropbox |
| **Playback** | | | |
| Tempo ranges | ±6/10/16/WIDE (100%) | same | ±4…100% (u) |
| Master tempo / beat sync / quantize | ✓ / ✓ / ✓ | ✓ / ✓ / ✓ | ✓ / ✓ / ✓ |
| Key sync / key shift | ✓ / ✓ (touchscreen) | ✓ / ✓ (u) | ✓ key match / ✓ key shift |
| Hot cues | 8 (A–H), colour | 8; Smart Cue, Gate Cue, Preview Hot Cue | 8 pads (cue/loop/roll/slicer) |
| Memory cues / saved loops | ✓ / ✓ | ✓ / ✓ | ✓ / 8 saved loops (u) |
| Loops | 4/8-beat auto, halve/double, in/out, reloop, odd lengths | same | auto + manual, roll |
| Beat jump | 1/2 to 64 beats | same | ✓ |
| Slip / reverse | ✓ / ✓ | ✓ / ✓ | ✓ / ✓ |
| Jog modes | VINYL/CDJ, jog adjust, display in jog | + JOG FEEL dial, wider range | Capacitive jog with display (SC6000); motorised 8.5" platter (M) |
| Needle / touch search | Touch Cue, Touch Preview, Link Cue | + Touch Cue | ✓ needle search (u) |
| Dual layer | ✗ | ✗ | **✓ (2 decks per unit)** |
| Stems | ✗ | ✗ | Engine 4.2 stems (desktop-rendered; paid licence on non-Prime-4+; SC6000 support u) |
| Full-track caching (USB pulled keeps playing) | ✓ | ✓ | n/s |
| **Display** | | | |
| Screen | 9" touch | 10.1" capacitive touch, 16 rows, dark/light mode | 10.1" touch |
| Waveforms | 3-band, RGB, blue; stacked (2 decks) | same | Engine colours; RGB since Engine 5.0 |
| Phrase | rekordbox PHRASE (sent for lighting; on-screen u) | same | ✗ (u) |
| Beatgrid edit on device | basic (u) | basic (u) | ✓ full-screen editor (Engine 2.4+) |
| **Connectivity** | | | |
| Link | Pro DJ Link, Gigabit Ethernet, up to 6 players | Pro DJ Link (1 LAN) + Wi-Fi | Engine/StageLinQ Ethernet |
| Lighting | Pro DJ Link Lighting (rekordbox + RB-DMX1), ShowKontrol | same | Engine Lighting / SoundSwitch (u details) |
| Software control | HID: Serato, djay, Traktor; rekordbox | HID: Serato, djay; rekordbox Performance unlocked | Serato / VirtualDJ (u) |
| Wi-Fi / Bluetooth | ✗ / ✗ | ✓ / ✗ | ✓ / ✗ |
| **Hardware** | | | |
| Outputs | RCA + coax digital | RCA + coax | 2× RCA + 2× coax |
| Audio | 96 kHz / 32-bit float processing | ESS DAC 96k/32, 115 dB S/N, 0.0018% THD | 96 kHz / 24-bit digital out |
| Power-loss safety | lockable V-Lock cable | locking IEC | n/s |
| Updates | USB firmware + Update Manager | online (u) | Engine OS updates via USB/online (u) |
| Boot time | unverified | unverified | unverified |

### 3b. AlphaTheta / Pioneer all-in-ones

| Feature | XDJ-XZ | XDJ-RX3 | OPUS-QUAD | XDJ-AZ | XDJ-AN |
|---|---|---|---|---|---|
| Channels | 4 (2 decks + 2 ext.) | 2 | 4 (4 decks) | 4 (4 decks) | 2 |
| Screen | 7" touch | 10.1" touch (not multi-touch) | 10.1" touch + 2 aux screens | 10.1" capacitive; 4-deck waveforms (fw 1.30) | 7" 1024x600 |
| Media | 2 USB | 2 USB-A + PC | 3 USB-A + USB-C PC | 3 USB-A + USB-C | USB-C only |
| On-device analysis | ✗ (u) | BPM only | promised at launch (u) | n/s | n/s |
| Streaming | ✗ (only via Serato/rekordbox) | ✗ (only via Serato) | Beatport, TIDAL (fw 1.22), Apple Music (fw 1.30) | Beatport, TIDAL (1.30), Apple Music (fw 2.00) | ✓ via rekordbox Cloud (services n/s) |
| Wi-Fi / Bluetooth in | ✗ / ✗ (u) | ✗ / ✗ | ✓ / ✓ | ✓ / ✓ BT 5.3 | ✓ (u) / ✓ |
| Key sync / shift | ✓ (u) | ✗ / ✗ | ✓ / ✓ (on screen) | ✓ / ✓ | ✗ / ✗ (standalone) |
| Hot cues (pads) | 8 | 8 pads, 6 modes, Gate Cue | 8 per deck | 8 pads, 8 modes, Gate Cue | pads = cues/loops only |
| Slip | ✓ (u) | ✓ (slip loop) | ✗ (per DDJT) | ✓ (u) | n/s |
| Beat FX / Colour FX | 14 / 6 | 14 / 6 + Release FX (8), X-pad | Beat FX + XY pad / DJM-class Colour FX | Beat FX + X-pad / 6 | 3 / 6 |
| Smooth Echo / Smart CFX | ✗ / ✗ (u) | ✗ / ✗ (u) | Smooth Echo ✓ / n/s | n/s | n/s |
| Sampler | ✗ (u) | ✗ (u) | ✗ | n/s | ✗ |
| Stems | ✗ | ✗ | ✗ | only as rekordbox controller | ✗ |
| Phrase display | ✓ (u) | ✓ PHRASE | n/s | n/s | n/s |
| Pro DJ Link | ✓ with built-in hub (first all-in-one) | ✗ (no Ethernet) | standalone lighting only (u) | ✓ 1 port, up to 2 CDJs, no hub | n/s |
| Mic inputs | 2 (u) | 2 | 2, feedback cancel | 2 | 1 |
| Outputs | master, booth (u) | master XLR+RCA, booth TRS | master XLR+RCA, booth, zone | master XLR+RCA, booth TRS, 2 phones | master XLR+RCA (shared), no booth |
| Recording to USB | ✓ (u) | ✓ WAV to USB 2 | n/s | ✓ | ✓ (USB or DJM-REC app) |
| Lighting | Pro DJ Link (u) | ✗ | ✗ (per DDJT) | n/s | n/s |
| DVS / timecode | ✓ (rekordbox) | ✗ | ✗ (u) | ✗ (u) | ✗ |
| Controller mode | rekordbox, Serato | rekordbox, Serato | rekordbox, Serato | rekordbox, Serato | rekordbox, Serato, djay (iOS) |
| Audio | n/s | n/s | n/s | 32-bit ESS | n/s |

### 3c. Engine DJ (Denon / Rane) all-in-ones

Engine DJ OS features shared by all models in this table (per Engine guides and release notes):

- library: playlists, search with BPM/key filters, history, playlist editing, on-device analysis
- full-screen beatgrid editor (Engine 2.4+)
- decks: 8 hot cues, auto and manual loops, slip, key shift
- streaming and lighting: Engine Lighting (Hue/Nanoleaf/DMX/SoundSwitch), Dropbox
- Engine 5.0 (May 2026): RGB waveforms, star ratings set on the hardware, import assistant for rekordbox/Serato libraries

| Feature | Prime 4+ | Prime 4 G2 | SC Live 4 | Prime Go+ | Rane System One |
|---|---|---|---|---|---|
| Channels | 4 | 4 | 4 | 2 | 2 |
| Screen | 10" touch | 10.1" 1280x800 multi-touch, tilting | 7" multi-touch | 7" multi-touch | 7" vertical touch (vertical/horizontal waveforms) |
| CPU / RAM | n/s | 8-core ARM, 4 GB | n/s | n/s | n/s |
| Media | USB + SD + SATA bay | 4 USB (2× C) + SD/SDXC + SATA bay | 2 USB + SD | USB + SD (u) | 3 USB-A + USB-C (locking) + SD + SATA bay |
| Streaming | Amazon, TIDAL, Beatport, Beatsource, SoundCloud (u) | Amazon, Apple Music, Beatport, SoundCloud Go+, TIDAL; Spotify "coming"; offline cache promised | TIDAL, SoundCloud Go+, Beatport, Beatsource, Amazon | Amazon, TIDAL, more | Apple, Amazon, Beatport, Beatsource, SoundCloud, TIDAL, Dropbox |
| Wi-Fi / Ethernet / BT | ✓ / ✓ / n/s | Wi-Fi 5 / **✗ removed** / BT 5.4 in + keyboard | ✓ / n/s / n/s | ✓ / ✗ (USB adapter) / n/s | ✓ / n/s / n/s |
| Stems | ✓ desktop-rendered (free, Engine 4.2) | **on-device rendering** + pre-rendered; acapella/instrumental buttons | desktop-rendered ($9.99 licence) | desktop-rendered (licence u) | **on-device since Engine 5.0** (May 2026) |
| Key sync | ✓ (u) | n/s | key shift ✓, sync n/s | ✓ (u) | n/s |
| Pads | 8/deck | 16 MPCe (velocity/pressure/3D) | 8 small/deck | 8/deck | RGB pads with OLED labels |
| FX | ~26 BPM FX + sweep (u) | 25+ main, 10 touch, 4 fader, 4 sweep, paddles | 4 sweep + 1 BPM FX | sweep + BPM FX (u) | 25+ main, 10 touch, 4 fader, 5 sweep, paddles |
| Sampler | n/s | ✓ (pad mode) | ✗ | n/s | n/s |
| Mic | 2 (u) | 2 (Mic2/instrument) | 1 (or aux) | 2 (u) | ✓ with reverb/echo, anti-feedback |
| Outputs | master, booth, zone (u) | main XLR+RCA, booth XLR, zone XLR; 10-band EQ per output | main XLR+RCA, booth TRS, built-in speakers | master, booth (u) | main XLR/RCA, booth TRS; 10-band EQ |
| Line/phono in | ✓ (u) | ch 3–4 line/phono | ✗ (aux only) | n/s | 1 aux, no phono |
| Lighting | Engine Lighting: Hue, Nanoleaf, SoundSwitch (u) | built-in DMX (1 universe) + Hue/Nanoleaf + SoundSwitch | Hue, Nanoleaf, DMX | n/s | n/s |
| Recording | ✓ (u) | n/s | n/s | n/s | n/s |
| Power | IEC | IEC 100 W | 12 V brick | battery (~4–6 h, sources differ) | IEC 150 W |
| Audio | n/s | ESS ES9017S DAC; files 44.1–192 kHz, 16–32-bit | n/s | n/s | n/s |
| Controller mode | Serato, VirtualDJ (u) | Serato/djay/VDJ "coming" | Serato Pro unlocked, VirtualDJ | Serato (u) | OmniSource: switch to computer mode without reboot |

---

## 4. Feature distribution

### Common to nearly all flagships

- **Pre-analysed library from desktop software:** rekordbox or Engine DJ export to USB, carrying BPM, beatgrid, key, coloured waveform and cues.
- **Big touchscreen browser:** 7" on entry/portable units, 9–10.1" on flagships. Touch to scroll and select, plus a waveform zoom control.
- **Search and filter:** text search with an on-screen keyboard, filtering by BPM, key and tag or rating, and a played-track history.
- **Coloured waveforms:** 3-band or RGB scrolling waveform with a full-track overview. Stacked or multi-deck waveforms on 4-deck units and the CDJ-3000.
- **Key lock and sync:** Master Tempo (keylock), Beat Sync and Quantize.
- **8 hot cues per deck:** coloured cues, plus memory cues and saved loops.
- **Loops and beat jump:** auto beat loop (4/8 buttons, halve/double), manual in/out with reloop, and beat jump.
- **Slip mode and reverse:** every device except OPUS-QUAD (per DDJT) has slip.
- **Tempo ranges:** selectable from ±6% to ±100% WIDE.
- **Wi-Fi streaming:** Beatport and TIDAL are near-universal on 2023+ units. Apple Music arrived in 2025–26 and Amazon on Denon.
- **Cloud library:** rekordbox CloudDirectPlay (Dropbox/Google Drive) or Engine Dropbox.
- **Controller mode:** every all-in-one doubles as a USB controller for rekordbox and/or Serato.
- **All-in-one I/O:** two mic inputs, balanced master plus booth outputs, and per-channel 3-band EQ with filter or Colour FX.
- **Beat-synced FX:** about 14–25 FX with an X/Y or touch pad.
- **Recording:** mix recording to USB on most all-in-ones.
- **Field firmware updates:** with new features added for years after launch, such as streaming services, 4-deck waveforms and stems.

### Only one or two have

- **On-device stem rendering:** only Prime 4 G2 and Rane System One (Engine 5.0+). Other Engine units play stems rendered on the desktop. No AlphaTheta standalone does stems.
- **Global Tag List with background download:** CDJ-3000X only. It is a cross-source temporary playlist that pre-caches streamed tracks for offline play.
- **NFC phone login:** CDJ-3000X only. Tapping a phone logs in to the rekordbox Cloud library.
- **Smart Cue and Gate Cue:** CDJ-3000X; Gate Cue also on XDJ-RX3/AZ. A hot cue that overwrites the main cue, and momentary hot-cue playback.
- **Pro DJ Link across 6 players with Link Cue:** CDJ-3000. Share one USB across players and preview another player's track through the mixer.
- **Full-track caching:** CDJ-3000/3000X. The whole track sits in RAM, so pulling the USB or losing the network doesn't stop playback.
- **Dual-layer decks:** SC6000/M only. One unit controls two decks.
- **Motorised platters:** SC6000M (8.5") and Rane System One (7.2"). Vinyl feel, with adjustable torque and stop time.
- **Built-in DMX output:** Prime 4 G2 (and SC Live 4). Pro lighting without an external interface; Engine also drives Hue and Nanoleaf.
- **Pro DJ Link Lighting via rekordbox PHRASE:** CDJ-3000/X. Phrase-aware light shows.
- **Phrase display on screen:** XDJ-RX3 (rekordbox PHRASE); other AlphaTheta units unverified. Song sections (intro/verse/chorus) are drawn on the waveform.
- **10-band output EQ for main, booth and zone:** Prime 4 G2 and Rane System One. Room tuning set on the touchscreen.
- **Zone output:** OPUS-QUAD and Prime 4 G2 (and Prime 4+). A third, independent output.
- **Internal SATA drive bay:** SC6000/M, Prime 4+/G2 and System One. The whole library lives inside the unit.
- **Built-in speakers:** SC Live 4/2 only.
- **Battery power:** Prime Go+ only.
- **MPCe velocity/pressure/3D pads:** Prime 4 G2 only.
- **Smooth Echo:** OPUS-QUAD. A one-knob automatic echo-out.
- **Release FX:** XDJ-RX3. Vinyl brake, backspin and echo-out "exit" effects.
- **Built-in Pro DJ Link hub and DVS:** XDJ-XZ. Plug CDJs straight in, and timecode via rekordbox.
- **On-device full-screen beatgrid editor:** Engine devices (2.4+). Multi-tempo anchors, tap and lock. Pioneer has only basic grid adjust (unverified).
- **On-device full analysis of unprepared files:** Engine devices. Pioneer relies on rekordbox prep or Cloud Analysis; XDJ-RX3 analyses BPM only.
- **Star ratings on hardware:** Engine 5.0.
- **OmniSource:** Rane System One and Prime 4 G2. Switch between standalone and computer-controller mode without a reboot.
- **USB-C-only media:** XDJ-AN.

### Not verified for any device in this pass

- boot time
- behaviour after a full power loss (all units need a reboot; no source quantified it)
- Ableton Link support on the hardware
- Smart Fader / Smart CFX in standalone mode (these appear to be rekordbox controller features)
- exact filesystem lists for Engine devices

---

## 5. Sources

Manufacturer:
- CDJ-3000 specs/features: https://www.pioneerdj.com/en/product/player/cdj-3000/black/specs/
- CDJ-3000X product page: https://alphatheta.com/en/product/dj-player/cdj-3000x/
- CDJ-3000X firmware 1.10 / 1.20: https://alphatheta.com/en/information/update-cdj-3000x-firmware-ver-1-10/ , https://alphatheta.com/en/information/update-cdj-3000x-firmware-ver-1-20/
- CDJ-3000X changelog (1.31, Apple Music): https://downloads.support.alphatheta.com/firmwares/dj-players/CDJ-3000X/CDJ-3000X-Firmware-Change-History-Ver131-en.pdf
- XDJ-RX3: https://www.pioneerdj.com/en/product/all-in-one-system/xdj-rx3/black/overview/
- OPUS-QUAD streaming update: https://alphatheta.com/en/information/opus-quad-omnis-duo-streamingdirectplay-support/ ; fw 1.30: https://www.pioneerdj.com/en/news/2025/opus-quad-firmware-update-ver-130
- XDJ-AZ fw 1.30: https://alphatheta.com/en/information/update-xdj-az-firmware-ver-1-30/
- rekordbox Apple Music notice (XDJ-AZ fw 2.00): https://rekordbox.com/de/2026/10/important-notice-update-required-to-continue-using-apple-music/
- XDJ-AN announcement: https://alphatheta.com/en/information/xdj-an-an-all-in-one-dj-system/
- SC6000M Prime: https://www.denondj.com/sc6000m-prime
- Prime 4 G2: https://www.denondj.com/prime-4-g2 ; https://enginedj.com/news/articles/introducing-denon-dj-prime-4-g2
- Engine DJ 2.4.0 release notes (beatgrid editor): https://enginedj.com/kb/solutions/69000828750/engine-dj-2-4-0-update-release-notes
- Engine stems setup: https://enginedj.com/kb/solutions/69000862383/engine-dj-stems-setup
- Engine user guides v5.3: https://cdn.inmusicbrands.com/engine/53/

Reviews and news:
- DJTT CDJ-3000X: https://djtechtools.com/2025/09/09/the-cdj-3000x-is-here-an-iterative-upgrade-of-the-media-player-for-3000-2399/
- DDJT CDJ-3000X: https://www.digitaldjtips.com/alphatheta-launches-cdj-3000x/
- RA CDJ-3000X Apple Music: https://ra.co/news/84280
- CDJ-3000 controls (VirtualDJ manual): https://virtualdj.com/manuals/hardware/pioneer/cdj3k/controls.html
- CDJ-3000 Beatport StreamingDirectPlay: https://www.attackmagazine.com/news/cdj3000s-introduce-streamingdirectplay-from-beatport/
- DDJT XDJ-RX3: https://www.digitaldjtips.com/?p=2769365
- Crossfader XDJ-XZ: https://wearecrossfader.co.uk/blog/the-pioneer-dj-xdj-xz-full-review-and-guide/
- DDJT OPUS-QUAD: https://www.digitaldjtips.com/reviews/pioneer-dj-opus-quad/
- DDJT XDJ-AZ: https://www.digitaldjtips.com/reviews/alphatheta-xdj-az-standalone-dj-system/
- Crossfader XDJ-AZ: https://wearecrossfader.co.uk/blog/xdj-az-review/
- DDJT XDJ-AZ fw 1.30: https://www.digitaldjtips.com/xdj-az-firmware-1-30-the-4-deck-update-is-finally-here/
- DDJT XDJ-AN: https://www.digitaldjtips.com/reviews/alphatheta-xdj-an-all-in-one-dj-system/
- DJTT XDJ-AN: https://djtechtools.com/2026/07/09/alphatheta-xdj-an-a-1200-standalone-2-channel-replacing-the-xdj-rr-only-takes-usb-c-drives/
- DDJT Prime 4 G2: https://www.digitaldjtips.com/reviews/denon-dj-prime-4-gen-2/
- Noisegate Prime 4 G2: https://noisegate.com.au/denon-dj-prime-4-g2-goes-big-on-stems-mpce-pads-and-standalone-performance/
- Mixdown Prime 4+: https://mixdownmag.com.au/reviews/review-denon-dj-prime-4-dj-system/
- DDJT SC Live 4/2: https://www.digitaldjtips.com/reviews/denon-dj-sc-live-4-sc-live-2/
- DDJT Prime Go+: https://www.digitaldjtips.com/denon-dj-prime-go-plus-news/
- DDJT Rane System One: https://www.digitaldjtips.com/reviews/rane-system-one-standalone/
- DJTT Engine DJ 5.0: https://djtechtools.com/2026/05/13/engine-dj-5-0-on-bard-stems-on-the-system-1-rgb-waveforms-for-everyone/
- DDJT Engine stems (4.2): https://www.digitaldjtips.com/?p=2788955
