# Boot Time

Measured on the CM5 IO board with the dev image (Touch Display 2, NVMe,
no controller connected), 2026-11-20. Method: `systemctl reboot` over
SSH, time until SSH answers again, minus the shutdown time and the
uptime at that moment (both from the journal, which is persistent);
the rest is firmware + bootloader. Accuracy about ±0.5 s. Mixxx window:
a small X client that waits until Mixxx's window is viewable.

## Where the time goes

| Phase | Time | Notes |
|---|---|---|
| Shutdown (before a restart) | 0.7 s | was 10.5 s, see below |
| Firmware + bootloader | ~8.0 s | old bootloader (2025-12-08): ~9--11 s; 2026-10-30 release: ~8.9 s; plus DecksmithOS settings: ~8.0 s |
| Kernel up to the initramfs | ~1.4 s | dev shows kernel messages on the panel; release boots `quiet` |
| initramfs (overlayroot) | ~1.3 s | read-only root; without it the kernel phase was 0.7--1.9 s |
| systemd up to the X session | ~2.1 s | DHCP runs in the background (dev) |
| Mixxx: start until its window is visible | ~0.6 s | plus up to 20 s waiting for the controller's USB audio when no controller is connected |

Power button to Mixxx with the controller connected: roughly 13--14 s
(estimate from the phases above; not timed end to end with a stopwatch).

## Changes made

- **Shutdown, 10.5 s to 0.7 s:** nodm answers SIGTERM by starting a new
  X session, whose processes never got the stop signal, so systemd
  waited 10 s for its stop timeout. `nodm.service.d/decksmithos-stop.conf`
  stops Mixxx first (SIGTERM, up to 15 s to save), then kills the rest
  of the session.
- **DHCP in the background (dev):** `auto eth0` held `network.target`
  and with it nodm and Mixxx.
- **Bootloader settings** (`/etc/decksmithos/bootloader.conf`, written
  by "Update bootloader" / "Apply bootloader settings" in the system
  menu): `BOOT_ORDER=0xf416` (NVMe first instead of eMMC/SD first),
  `BOOT_UART=0`, `NET_INSTALL_AT_POWER_ON=0`, `DISABLE_HDMI=1`.

## Still possible

- **initramfs (~1.3 s):** only `overlayroot` needs it. Options: skip
  the root fsck (the root is never written), a smaller initramfs
  (`MODULES=list`), or a minimal custom init that sets up the overlay
  (~0.1 s, but replaces Debian's `overlayroot`).
- **Firmware + bootloader (~8 s):** the largest part. The bootloader
  log on the debug UART (`BOOT_UART=1`) would show where the time goes;
  needs a UART adapter. A smaller initramfs is also read faster.
- **No controller:** the 20 s wait for USB audio (`DECKSMITHOS_AUDIO_WAIT`
  in `decksmithos-mixxx`) could be shorter.
