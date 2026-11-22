#!/bin/bash
# Export every printable part of the enclosure to hardware/enclosure/stl/.
# One-piece parts (body, tray) are for 220+ mm beds; the split ones
# (body_left/right, tray_left/right, tray_splice) for 180 mm beds.
# Extra arguments are passed to OpenSCAD, e.g.: export.sh -D glass_front_z=40
set -Eeuo pipefail
cd "$(dirname "$0")"
mkdir -p stl
parts=(body tray body_left body_right tray_left tray_right tray_splice tongue sw1_pin
       template_rim template_board template_display)
for p in "${parts[@]}"; do
  echo "exporting ${p}"
  openscad -q -o "stl/${p}.stl" -D "part=\"${p}\"" "$@" decksmithos-enclosure.scad
done
