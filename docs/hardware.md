# Hardware Architecture

DecksmithOS is designed to support modular hardware configurations.

The system should remain controller-agnostic.

---

## Core Hardware

Minimum configuration:
- Raspberry Pi 4 or 5
- SSD storage
- USB DJ controller
- primary touchscreen display

---

## Optional Hardware

DecksmithOS supports additional components:
- auxiliary displays
- lighting controllers
- MIDI devices
- external storage

---

## Display Architecture

### Primary Display

Used for:
- waveform display
- library browser
- system status

Typical sizes:
3.5 inch
5 inch
7 inch
10 inch
11 inch

---

### Auxiliary Displays

Optional displays can provide additional information:

Examples:
- deck status panels
- FX control
- sampler control

These displays may be driven by external microcontrollers.

Example architecture:
Raspberry Pi
↓
UI Bus
↓
ESP32 Display Panels


This approach reduces system load and improves UI responsiveness.

---

## Controller Integration

DecksmithOS relies on controller support provided by Mixxx.

Controllers communicate using:
USB HID
USB MIDI


DecksmithOS itself does not implement controller-specific logic.

---

## Audio Routing

Audio output is expected to be handled by the DJ controller hardware.

Typical outputs:
- master output
- booth output
- headphone cue

This avoids unnecessary routing through the Raspberry Pi audio subsystem.


DecksmithOS itself does not implement controller-specific logic.

---

## Audio Routing

Audio output is expected to be handled by the DJ controller hardware.

Typical outputs:
- master output
- booth output
- headphone cue

This avoids unnecessary routing through the Raspberry Pi audio subsystem.
