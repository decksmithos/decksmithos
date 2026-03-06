# DecksmithOS

DecksmithOS is a purpose-built Linux appliance designed to transform standard USB DJ controllers into fully standalone DJ systems.

The system targets Raspberry Pi hardware and provides a reproducible operating system image optimized for:
- low-latency audio performance
- touchscreen-based DJ interfaces
- hardware controller integration
- appliance-style boot behavior
- firmware-style system updates

DecksmithOS is designed to behave like a dedicated DJ device rather than a general-purpose Linux computer.

---

# Design Philosophy

DecksmithOS follows several core design principles.

### Appliance-first architecture

The system boots directly into DJ mode.

There is no desktop environment and no traditional user interaction with the operating system.

---

### Deterministic builds

Every system image must be reproducible from the repository.

The repository contains:
- build scripts
- configuration
- filesystem overlays

The base Linux system is downloaded or cached during the build process.

---

### Minimal Linux footprint

Only strictly required components are included.

The runtime system removes or disables:
- unnecessary services
- development tools
- package managers

The goal is a predictable and stable runtime environment.

---

### Read-only operating system

The root filesystem is mounted read-only during normal operation.

Advantages:
- filesystem integrity
- protection against corruption
- predictable system state
- improved SSD endurance

All mutable data is stored on the `storage` partition.

---

### Firmware-style updates

DecksmithOS does not support manual system upgrades.

System updates are delivered as new firmware images.

Updates are applied using an **A/B root filesystem strategy**.

---

# Default Linux User

DecksmithOS uses the following system user:
username: dj
home: /home/dj

The default Raspberry Pi user (`pi`) is not used.

---

# Repository Structure

decksmithos/
│
├─ build/ OS build system
├─ overlay/ Filesystem overrides
├─ packages/ Package installation lists
├─ scripts/ Build and maintenance scripts
├─ hardware/ Hardware integration modules
├─ docs/ System documentation
└─ tools/ Update and service tools

---

# System Architecture

DecksmithOS consists of the following layers:
Hardware
↓
Linux Kernel
↓
Minimal System Services
↓
DecksmithOS Runtime
↓
Mixxx DJ Engine
↓
User Interface

The user interacts only with the DJ interface.

---

# Boot Flow
Bootloader
↓
Linux Kernel
↓
System Initialization
↓
DecksmithOS Runtime
↓
Mixxx Launch

The system boots directly into Mixxx in fullscreen mode.

---

# Storage Layout

DecksmithOS uses a firmware-style partition layout designed for reliability and safe updates.
Disk
│
├─ boot (FAT32)
├─ rootfs_A (ext4)
├─ rootfs_B (ext4)
└─ storage (ext4)

---

## Boot Partition

Filesystem:
FAT32

Typical size:
256 MB

Contents:

- bootloader
- kernel
- device tree
- boot configuration

---

## Root Filesystems

Two root filesystem partitions are used:
rootfs_A
rootfs_B

One partition is active while the other remains inactive.

Updates are written to the inactive partition.

Filesystem:
ext4

Typical size per partition:
2 GB

The root filesystem contains:

- minimal Linux base system
- DecksmithOS runtime
- Mixxx
- hardware support components

Root filesystems are mounted read-only during normal operation.

---

## Storage Partition

The storage partition contains all mutable data.

Filesystem:
ext4

Typical contents:
/storage
/library
/recordings
/logs
/config
/exports
/cache

### Directory purposes
/library
Music library and metadata.

/recordings
Recorded DJ sets.

/logs
System and application logs.

/config
User configuration and controller mappings.

/exports
Exported playlists and sets.

/cache
Temporary runtime cache.

---

# Minimum Storage Requirements

DecksmithOS is designed to run on small SSD or NVMe drives.

Recommended configuration:
64 GB SSD/NVMe

Typical layout example:
- boot: 256 MB
- rootfs_A: 2 GB
- rootfs_B: 2 GB
- storage: remaining space

This leaves tens of gigabytes available for music storage.

DecksmithOS can also operate on smaller drives:
16 GB minimum

With reduced library capacity.

---

# SSD Overprovisioning

To improve SSD endurance and garbage collection efficiency, approximately:
15% of the disk capacity

should remain **unallocated**.

This space should not belong to any partition.

---

# Update Mechanism

DecksmithOS uses a firmware-style update process.

Update procedure:
- Determine active root slot (A or B)
- Write new root filesystem to inactive slot
- Switch boot target
- Reboot

If the new system fails to boot, the bootloader can revert to the previous root slot.

This approach provides safe rollback capability.

---

# Target Hardware

Current target platform:
- Raspberry Pi 4
- Raspberry Pi 5
- NVMe SSD storage
- USB DJ controller
- primary touchscreen display

Optional components:
- auxiliary display panels
- MIDI controllers
- lighting controllers

---

# Development Status

Current milestone:
Boot to Mixxx

The goal of the first milestone is to produce a reproducible system image that boots directly into Mixxx.

---

# License

DecksmithOS is released under the **Apache License, Version 2.0**.

This license allows:
- reuse
- modification
- redistribution
- commercial use

while keeping attribution requirements minimal.

See the LICENSE file for details.

---

## Trademark

DecksmithOS and the DecksmithOS logo are trademarks.

Use of the DecksmithOS name or logo in commercial products requires explicit permission.

Forks and derivative works must not use the DecksmithOS name or branding without authorization.