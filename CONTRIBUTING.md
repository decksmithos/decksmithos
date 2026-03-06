# Contributing to DecksmithOS

Thank you for your interest in contributing to DecksmithOS.

The goal of the project is to create a stable, reproducible operating system for standalone DJ systems.

---

# Development Principles

Contributions should follow the core design principles of DecksmithOS:

- appliance-style system behavior
- minimal runtime complexity
- reproducible builds
- hardware abstraction
- deterministic system configuration

---

# Repository Structure

build/
overlay/
packages/
scripts/
hardware/
docs/
tools/

Each directory has a specific purpose.

Contributions should maintain the existing structure.

---

# Contribution Types

We welcome contributions in several areas.

### System Development

- boot process improvements
- hardware compatibility
- runtime optimization

### User Interface

- Mixxx skin improvements
- touchscreen usability
- controller integration

### Hardware Integration

- auxiliary displays
- MIDI devices
- controller hardware

### Documentation

- architecture documentation
- hardware guides
- development guides

---

# Development Workflow

1. Fork the repository.
2. Create a feature branch.

Example:


feature/display-panels
feature/update-system
feature/ui-layout


3. Implement your changes.
4. Submit a merge request.

---

# Code Style

General guidelines:

- use clear and descriptive naming
- prefer simplicity over complexity
- document non-obvious logic
- keep scripts portable and readable

All comments should be written in English.

---

# Commit Messages

Use clear commit messages describing the purpose of the change.

Example:
Add DecksmithOS splash screen configuration


Avoid vague messages such as:


fix stuff


---

# Testing

Changes should be tested on real hardware when possible.

Target platforms:
- Raspberry Pi 4
- Raspberry Pi 5

---

# Licensing

All contributions must be compatible with the Apache 2.0 license used by DecksmithOS.

By submitting a contribution, you agree that your code may be distributed under this license.

---

# Thank You

DecksmithOS aims to build a strong open community around standalone DJ systems.

Your contributions help improve the project for everyone.
