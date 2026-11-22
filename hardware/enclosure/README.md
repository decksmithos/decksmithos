# DecksmithOS enclosure (CM5 IO Board R2 + Touch Display 2, 7")

A printable enclosure that stands behind the DJ controller (behind its RCA
outputs, in the middle), with the screen tilted towards the DJ like the
XDJ-RX3's (about 24 degrees from horizontal), and a thin "tongue" that goes
under the controller and is held with double-sided tape or Dual Lock.

The enclosure is as large as the display's glass (189.32 x 120.24 mm, R8),
plus 1.05 mm per side: the glass is the top face, in a pocket 0.2 mm larger
than the glass, whose rim (0.85 mm, two lines of a 0.4 mm nozzle) stands
0.5 mm above the glass face and protects its edge. Under the glass a 4 mm
ledge (0.5 mm below it: room for foam tape) closes the gap to the walls. The
display hangs on its four M2.5 brackets from four rails on the side walls.
The CM5 IO board sits on the removable bottom tray: with the tray off, the
board, its NVMe and its RTC battery are reachable without touching the
display. A 40 mm fan at the back pulls air in through the tray and the low
side slots (taller at the front, lower towards the back, under the display rails).

**Status: second draft, not printed yet.** Hole and connector positions come
from the official design files (see Sources); the display from its mechanical
drawing (glass, metal back 168.55 x 99.71 with 6.45 mm of glass on the left,
14.32 right, 10.265 front and back; brackets at 140 x 70.71, centred). Print the
templates first and check them against the real board and display.

## Parts

| Part | Size (mm) | Bed | Notes |
|---|---|---|---|
| `body` | 191 x 112 x 92 | 220+ (Ender 3) | walls, glass pocket, display rails, fan grille, ports at the back |
| `tray` | 191 x 112 x 8 | 220+ | bottom with the board standoffs, intake vents, feet recesses |
| `body_left`, `body_right` | 96 x 112 x 92 | 180 (A1 mini) | the body in two halves, joined by two M3 screws |
| `tray_left`, `tray_right` | 96 x 112 x 8 | 180 | the tray in two halves |
| `tray_splice` (x2) | 22 x 14 x 1.6 | any | joins the tray halves underneath |
| `tongue` | 80 x 145 x 16 | any | 3 mm under the controller, 6 mm across the RCA gap, flange to the body |
| `sw1_pin` | 7 x 7 x 20 | any | pushes the board's own power button through the front wall (fallback) |
| `template_rim` | 191 x 122 x 3.7 | 220+ | test print: the glass must drop into it with a little play |
| `template_board` | 150 x 86 x 1.6 | any | test print: board mounting holes |
| `template_display` | 154 x 85 x 1.6 | any | test print: display bracket holes |

Export all STL files:

```sh
hardware/enclosure/export.sh            # writes hardware/enclosure/stl/ (not in git)
```

## Print settings

- PETG or ASA, not PLA (softens in a hot car or near stage lights).
- 0.2 mm layers, 3 walls, 20-25 % infill; the tongue 100 % (it is thin).
- Line width 0.42 mm or less, so that the 0.85 mm rim is two whole lines.
- The body prints as it stands (open bottom on the bed, rim on top), no
  supports: the rails under the display brackets have 45 degree undersides.
- The tray prints as it is (standoffs up).

## Other parts

- 4 x M2.5 x 6 screws for the display brackets, hex socket (the display comes
  with eight M2.5 screws; check their length: 3.5 mm of rail plus ~2.5 mm in
  the bracket). They go in from below, along the screen's normal: a short
  hex key reaches the back ones (a straight screwdriver hits the back wall).
- 4 x M2.5 x 6 self-tapping screws for the board.
- M3 heat-set inserts (4.2 mm holes, 5 mm long; check yours): 6 in the body
  for the tray, 2 in the front wall for the tongue, and in the split body 2
  more in the right half's joint blocks.
- M3 screws: 6 x M3 x 8 countersunk (tray), 2 x M3 x 8 (tongue), split
  version: 2 x M3 x 12 (body halves) and 4 x M3 x 8 with nuts (tray splices).
- A 40 mm 5 V PWM fan with a 4-pin JST-SH plug (as for the Pi 5), to J14,
  with 4 screws through the back wall. `dtparam=cooling_fan=on` in the image
  lets the kernel run it by the SoC temperature.
- A 12 mm momentary push button (normally open) and two Dupont jumper wires
  to the board's J2 pins 13-14 ("Wake/shutdown button", CM5IO datasheet,
  section 5.1). It acts like the board's own power button: a short press
  opens the DecksmithOS system menu, a long press powers off.
- 0.5 mm foam tape for the ledge under the glass (optional).
- 4 rubber feet, 10 mm.
- Double-sided tape (3M VHB) or 3M Dual Lock (removable) for the tongue.
- Display cables long enough for the tray to come out: see "Cables".

## Cables

The display sits with its narrow glass margin on the left (rotated 180 degrees
from the way it is drawn; the image rotates the picture and touch to match).
That brings its DSI and power connectors to the right of the centre, near the
board's CAM/DISP 0 connector (J5, front right corner) and the GPIO header
(right edge). Straight-line distances from the model: about 81 mm for the
ribbon to J5 (65 mm to J16) and about 80 mm for the power cable (78-104 mm
depending on which end of the header carries pins 2/4/6), before any slack
to lower the tray. The 100 mm ribbon that came with the display fits; the
80 mm power cable is at the limit, so a slightly longer 2-wire 5 V lead is
safer. With the display the other way round (narrow margin on the right) the
ribbon would need about 105 mm.

## Assembly

1. Heat-set the M3 inserts into the body (tray bosses, tongue bosses, and in
   the split body the right half's joint blocks). Split body: join the halves
   (2 x M3 x 12 from the left half).
2. Display: foam tape on the ledge if used, the glass into the pocket from
   above, then the 4 M2.5 screws from below through the rails into its
   brackets. Plug in its ribbon and power cable.
3. Fan to the back wall (label inwards, blowing out), cable to J14.
4. Board onto the tray (split tray: splices underneath first), M2.5 screws.
5. Plug the ribbon into J5 and the display power into the GPIO header
   (5 V, GND), the button wires into J2 13-14, then lift the tray into the
   body, ports into the back slots, and screw it from below (6 x M3).
6. Tongue to the body's front wall (2 x M3), tape on its top face, slide it
   under the controller.

## Parameters worth checking

| Parameter | Default | Meaning |
|---|---|---|
| `bracket_face` | 8.5 | glass face to the brackets' screw face; **measure** (drawing value) |
| `glass_t` | 0.7 | glass thickness at the edge (measured) |
| `glass_clear`, `rim_t`, `rim_above` | 0.2, 0.85, 0.5 | pocket play, rim thickness, rim height above the glass |
| `tilt` | 24 | screen angle; measure an XDJ-RX3 with an inclinometer if you can |
| `glass_front_z` | 45 | height of the glass face at its front edge; lower = flatter box, less room above the board |
| `rca_gap` | 45 | controller back to enclosure front: room for the RCA plugs |
| `tongue_under` | 100 | how far the tongue goes under the controller |
| `tongue_t` | 3 | must stay below the controller's ground clearance (5-6 mm measured) minus the tape |
| `fan_x`, `fan_z` | 65, 52 | fan centre on the back wall (above USB-C and USB) |
| `sd_skin` | 0.8 | back wall left in front of the microSD slot (cut out to use the card) |
| `button_d` | 12 | panel button hole; 0 for none |

OpenSCAD prints the box size and the display's clearances in its console.

## Sources

- CM5 IO Board R2 KiCad files (hole and connector positions):
  https://pip.raspberrypi.com/categories/1098-design-files
- CM5 IO Board datasheet (outline, J2 pins 13-14):
  https://datasheets.raspberrypi.com/cm5/cm5io-datasheet.pdf
- Touch Display 2 product brief, 7" mechanical drawing (glass 189.32 x
  120.24 mm R8, metal back, bracket holes, depths):
  https://pip-assets.raspberrypi.com/categories/1083-raspberry-pi-touch-display-2/documents/RP-009106-MM-7-touch-display-2-product-brief.pdf
- XDJ-RX3 screen angle: about 24 degrees, estimated from published outer
  dimensions (not an official figure).
