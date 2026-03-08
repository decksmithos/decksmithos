# Building DecksmithOS

## Overview

DecksmithOS uses the official Raspberry Pi OS image generation tool:

```text
pi-gen

The local build wrapper:

build/build.sh

is responsible for:

cloning or updating the official pi-gen repository

copying DecksmithOS-specific configuration and stages into that checkout

running the official image build process

optionally post-processing the resulting image into the DecksmithOS A/B disk layout

For 64-bit Raspberry Pi OS images, the correct pi-gen branch is:

arm64

This is required by the official pi-gen project.

Repository Layout

Relevant files and directories:

build/
├─ .gitignore
├─ build.sh
├─ config
├─ postprocess-ab.sh
└─ stage-decksmithos/
   ├─ 00-packages
   ├─ 00-run.sh
   └─ 01-run.sh

Notes:

build/pi-gen/ is cloned locally and is not committed to Git.

DecksmithOS build logic lives in this repository.

pi-gen remains an external upstream dependency.

Host Requirements

A Debian or Ubuntu host is recommended.

Minimum practical requirements:

Git

rsync

sudo

Bash

enough free disk space for image builds

no spaces in the repository path

The pi-gen ecosystem is sensitive to unsupported host configurations and path edge cases. A simple Debian/Ubuntu build host is the safest choice.

First Build

Run the build from the repository root:

cd build
chmod +x build.sh
./build.sh

The script will:

clone or update the official pi-gen repository into build/pi-gen

copy the DecksmithOS build configuration into that checkout

run the official pi-gen build process

place the generated image in:

build/pi-gen/deploy/
Current Build Scope

The current milestone is:

Boot to Mixxx

The current image build is expected to provide:

Raspberry Pi OS Lite 64-bit base

user dj

automatic login through nodm

Xorg + Openbox

Mixxx fullscreen launch

DecksmithOS runtime basics

primary SPI touchscreen support for a 3.5" 480×320 panel

The following items are not yet final at this stage:

immutable rootfs

A/B firmware update tooling

runtime package manager removal

full storage migration of all writable paths

final production-grade touchscreen calibration

A/B Image Post-Processing

The standard pi-gen output is still a conventional Raspberry Pi OS image.

DecksmithOS converts that image into its firmware-style layout using:

build/postprocess-ab.sh

Target partition layout:

boot
rootfs_A
rootfs_B
storage

The initial boot target is:

rootfs_A

This post-processing step is intentionally separate from the base pi-gen build.

SPI Display Support

DecksmithOS currently supports using a 3.5" 480×320 SPI touchscreen as the primary display.

Because these panels vary by vendor, the build is controlled through variables in:

build/config

Primary variables:

DECKSMITHOS_PRIMARY_DISPLAY='spi35'
DECKSMITHOS_SPI_DTO='waveshare35b-v2'
DECKSMITHOS_SPI_ROTATION='90'
DECKSMITHOS_SPI_TOUCH_PRODUCT='ADS7846 Touchscreen'
DECKSMITHOS_SPI_FB='/dev/fb1'

Important:

the correct dtoverlay= value depends on the actual panel

many 3.5" SPI Raspberry Pi panels use ILI9486 with XPT2046 or ADS7846-style touch controllers

Waveshare documents overlays such as waveshare35a and waveshare35b-v2

LCDWiki documents similar 3.5" 480×320 SPI panels using ILI9486 + XPT2046

If the display works but touch orientation is wrong, only the touchscreen calibration or rotation values should be adjusted.

Expected Runtime Behavior for SPI Primary Display

When DECKSMITHOS_PRIMARY_DISPLAY='spi35' is enabled, the build configures:

SPI support in Raspberry Pi boot configuration

vendor overlay loading through dtoverlay=...

framebuffer selection for Xorg

FRAMEBUFFER=/dev/fb1

a dedicated Xorg fbdev device section

basic touchscreen calibration file

This keeps the SPI panel as the UI target during early DecksmithOS bring-up.

Known Limitations

The current 3.5" SPI display support is intended for initial bring-up and development.

Practical limitations:

SPI displays are slower than DSI/HDMI displays

waveform-heavy UI layouts may need simplification

final production UX should prefer the 5" or 7" primary display

touch calibration may require model-specific tuning

Recommended Build Phases
Phase 1

Bootable Lite image with DecksmithOS runtime and SPI primary display

Phase 2

A/B image layout and cmdline slot switching

Phase 3

Read-only rootfs and full writable path migration to /storage

Phase 4

Firmware-style updater and rollback handling

## Switching the Active Root Slot

DecksmithOS uses `cmdline.txt` root switching for A/B boot selection.

Utility script:

```text
build/switch-rootfs.sh

Behavior:

detects the current cmdline.txt

resolves the PARTUUID of rootfs_A and rootfs_B

rewrites the root=PARTUUID=... kernel argument

Examples:

sudo ./build/switch-rootfs.sh
sudo ./build/switch-rootfs.sh A
sudo ./build/switch-rootfs.sh B

This is the initial boot slot switching mechanism used by DecksmithOS.

A more advanced updater with rollback validation may replace this workflow in later versions.
