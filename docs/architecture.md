# DecksmithOS Architecture

## Overview

DecksmithOS is designed as a minimal Linux appliance optimized for DJ performance.

The system architecture separates the platform into the following layers:
Hardware
↓
Linux Kernel
↓
Minimal System Services
↓
DecksmithOS Runtime Layer
↓
Mixxx DJ Engine
↓
User Interface

The goal is to reduce unnecessary system complexity while maintaining high stability and reproducibility.

---

## System Layers

### 1. Hardware Layer

Primary hardware platform:
- Raspberry Pi 4 / 5
- NVMe SSD storage
- USB DJ controller
- Primary touchscreen display
- Optional auxiliary displays

---

### 2. Kernel Layer

The Linux kernel is responsible for:
- USB device handling
- Audio subsystem
- SPI/I2C peripherals
- Storage management

Kernel modifications should be avoided unless strictly necessary.

---

### 3. System Layer

This layer provides minimal Linux functionality:
- systemd
- networking (optional)
- storage management
- device detection

Unnecessary services are disabled.

---

### 4. DecksmithOS Runtime

The runtime layer provides appliance-style behavior:
- splash screen
- automatic login
- display initialization
- controller detection
- Mixxx launcher

This layer is implemented through system configuration and lightweight scripts.

---

### 5. DJ Engine

DecksmithOS currently uses:
Mixxx

Mixxx provides:
- audio engine
- controller mappings
- waveform rendering
- library management

Future engines could theoretically be supported.

---

### 6. User Interface

The UI consists of:
- touchscreen interface
- controller hardware
- optional auxiliary display panels

UI layouts adapt based on display size.

---

## System Boot Flow

Bootloader
↓
Linux Kernel
↓
System Initialization
↓
DecksmithOS Runtime
↓
Mixxx Launch

The user should never interact with a traditional desktop environment.

---

## Design Goals

The architecture aims to provide:
- fast boot time
- deterministic behavior
- minimal system noise
- predictable hardware interaction
