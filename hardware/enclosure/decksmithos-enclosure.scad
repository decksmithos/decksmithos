// DecksmithOS enclosure: Raspberry Pi CM5 IO Board (R2) + Touch Display 2 (7")
// sitting behind the DJ controller, screen tilted towards the DJ, with a
// "tongue" that goes under the controller (double-sided tape / Dual Lock).
//
// The enclosure is exactly as large as the display's glass: the glass is the
// top face, held in a pocket whose 2-line rim stands 0.5 mm above the glass
// (protects its edge from knocks). The display hangs on its four M2.5 brackets
// from four rails; the CM5 IO board sits on the removable bottom tray, so the
// board, its NVMe and its RTC battery come out from below without touching the
// display. A 40 mm PWM fan (board connector J14) blows out at the back.
//
// Parametric (OpenSCAD 2021+). Export one part at a time:
//   openscad -D 'part="body"' -o body.stl decksmithos-enclosure.scad
// Parts: body, tray (one piece: Ender 3 and other 220+ mm beds), body_left,
//        body_right, tray_left, tray_right, tray_splice (Bambu A1 mini and
//        other 180 mm beds), tongue, sw1_pin, template_rim, template_board,
//        template_display, assembly (preview).
// Print the body as it stands (open bottom on the bed, rim up): no supports.
//
// World axes (assembly): X = left-right as the DJ sees it, Y = depth (Y=0 at
// the front, towards the DJ and the controller; the ports face +Y, the back),
// Z = up. Units: mm. "Glass frame" (u, v, w): u along X from the glass's left
// edge, v up the slope from its front edge, w out of the glass (w=0 on its
// face, negative into the enclosure).
//
// Sources (see README.md): CM5 IO Board R2 KiCad files (hole and connector
// positions), CM5IO datasheet (J2 pins 13-14: external power button; J14 fan),
// Touch Display 2 7" product brief, mechanical drawing (glass 189.32 x 120.24
// R8, metal back 168.55 x 99.71 offset 6.45 / 10.265, brackets 140 x 70.71).
// MEASURE BEFORE THE FINAL PRINT: print template_rim (glass fit) and
// template_display / template_board (holes) first; check bracket_face.

/* [Part] */
part = "assembly"; // [assembly, body, tray, body_left, body_right, tray_left, tray_right, tray_splice, tongue, sw1_pin, template_rim, template_board, template_display]

/* [Screen] */
tilt = 24;              // screen tilt from horizontal (XDJ-RX3 ~24 deg, estimated)
glass_front_z = 45;     // height of the glass face at its front edge (feet excluded)

/* [Display: Touch Display 2, 7", landscape, narrow glass margin on the left] */
// Mounted with the narrow margin on the left (rotated 180 degrees from the
// first draft) so that its DSI and power connectors come close to J5 and the
// GPIO header at the board's right edge; the image rotates the panel to match.
glass_w = 189.32; glass_d = 120.24; glass_r = 8;
glass_t = 0.7;          // cover glass thickness at the edge (measured by the user)
// metal back: 168.55 x 99.71; glass margin 6.45 left, 14.32 right, 10.265 front/back
metal_w = 168.55; metal_d = 99.71; metal_left = 6.45; metal_front = 10.265;
disp_holes_dx = 140; disp_holes_dy = 70.71;   // bracket M2.5 holes, centred on the glass
bracket_face = 8.5;     // glass face to the brackets' screw face (drawing; MEASURE)
disp_depth = 14.92;     // glass face to the lowest part of the display (drawing)

/* [Glass pocket] */
glass_clear = 0.2;      // gap between the glass edge and the rim, each side
rim_t = 0.85;           // rim thickness: 2 lines of a 0.4 mm nozzle
rim_above = 0.5;        // rim height above the glass face
ledge_gap = 0.5;        // ledge below the glass: room for 0.5 mm foam tape (or air)
ledge_w = 4;            // ledge width under the glass, from the glass edge inwards
ledge_t = 2;

/* [Rails for the display brackets] */
rail_half = 5;          // half width (along the slope)
rail_past = 6;          // how far the rail reaches past the bracket hole
pad_t = 3.5;            // rail material the M2.5 screw passes (screw = pad_t + ~2.5 mm: M2.5 x 6)

/* [Fan] */
fan = 40;               // 40 mm, 5 V PWM (JST-SH 4-pin to J14); 0 = grille only, no fan holes
fan_x = 65;             // centre, from the left outer face: above USB-C and USB, clear of the
                        // back joint block of the split body (fan edge <= mid - joint_half)
fan_z = 52;             // centre height
fan_holes = 32;         // screw hole spacing of a 40 mm fan

intake_h = [21.3, 16, 10.7, 5.3];  // side intake slot heights, front to back

/* [Tongue under the controller] */
tongue_under = 100;     // length under the controller
rca_gap = 45;           // space between the controller's back and the enclosure (RCA plugs)
tongue_w = 80;          // width
tongue_t = 3;           // thickness under the controller (clearance there ~5-6 mm, tape ~1 mm)
tongue_gap_t = 6;       // thickness of the part between enclosure and controller

/* [Power button] */
button_d = 12;          // panel push button (normally open) in the left wall, wired to J2 pins 13-14; 0 = none
button_y = 52;          // its position on the left wall (depth, height)
button_z = 45;

/* [Print] */
wall = 3;
tray_t = 3;
insert_d = 4.2;         // hole for M3 heat-set inserts (check your inserts)
insert_len = 5;
m3_clear = 3.4;
m25_clear = 2.9;
$fn = 40;

// ---------------------------------------------------------------------------
// Board: CM5 IO Board R2, 160 x 90 x 1.6. Board coordinates (bx, by): origin at
// the lower-left corner seen from the top, with the port edge at by = 0
// (KiCad x - 13.2, KiCad y).
pcb_w = 160; pcb_d = 90; pcb_t = 1.6;
standoff_h = 5;
board_holes = [[11.0, 8.0], [132.5, 8.0], [11.0, 77.0], [132.5, 77.0]]; // H1 H8 H7 H6 (M2.5)
// Port cut-outs in the back wall: [bx centre, width, height, bottom above the PCB top]
// (sized for the plugs' bodies, not just the sockets)
ports = [
    [23.0, 21, 11, -2.0],   // HDMI0 (J22)
    [48.0, 21, 11, -2.0],   // HDMI1 (J10)
    [74.0, 18, 15.5, -0.5], // Ethernet (U3)
    [93.0, 17, 18, -0.5],   // 2x USB 3 (J12)
    [108.0, 13, 7.5, -2.0], // USB-C power in (J11)
];
// microSD (J7): not exposed. The back wall is thinned to sd_skin in front of it;
// cut the skin out to reach the card. [bx centre, width, height, bottom above the PCB top]
sd_slot = [122.1, 15, 3.5, -1.0];
sd_skin = 0.8;
sw1 = [27.25, 87.1];        // power button SW1, right-angle, presses towards +by edge
sw1_h = 3.5;                // actuator centre above the PCB top (PTS645 right angle, approx.)
j5 = [11.5, 85];            // CAM/DISP 0 (display ribbon), front edge

// ---------------------------------------------------------------------------
// Derived sizes
st = sin(tilt); ct = cos(tilt);
rim_out = glass_clear + rim_t;             // outer face beyond the glass edge
w_j = -(glass_t + ledge_gap);              // ledge top (glass frame)
body_w = glass_w + 2 * rim_out;
// the rim's outer face is square to the glass, so tilted: at the front its top
// leans out by rim_lean. The front wall is moved out by that much, so that the
// rim stands on a vertical wall (no overhang outside the box).
rim_lean = (rim_above - w_j) * st;
body_d = (glass_d + 2 * rim_out) * ct + rim_lean;   // plan depth of the walls
mid = body_w / 2;
// glass frame origin (glass face, front-left corner of the glass) in world coordinates;
// the walls' front face is at y = 0 (level with the rim's top front edge)
G0 = [rim_out, rim_out * ct + w_j * st + rim_lean, glass_front_z];
function gx(u) = G0[0] + u;
function gy(v, w) = G0[1] + v * ct - w * st;
function gz(v, w) = G0[2] + v * st + w * ct;

pcb_z = tray_t + standoff_h;               // PCB bottom
pcb_top = pcb_z + pcb_t;
board_x0 = (body_w - pcb_w) / 2;
board_back = body_d - wall - 0.5;          // port edge
function bx2x(bx) = board_x0 + (pcb_w - bx);
function by2y(by) = board_back - by;

brackets = [for (sx = [-1, 1], sy = [-1, 1]) [glass_w / 2 + sx * disp_holes_dx / 2, glass_d / 2 + sy * disp_holes_dy / 2]];

// Clearance report (shown in the console)
disp_low_front = gz(metal_front, -disp_depth);
echo(str("body ", body_w, " x ", body_d, " mm, rim front ", gz(-rim_out, rim_above), " back ", gz(glass_d + rim_out, rim_above),
         "; display lowest at the front ", disp_low_front, " (board top ", pcb_top, ")"));
echo(str("display back at the back wall: ", body_d - wall - gy(glass_d - metal_front, -disp_depth), " mm clearance"));

// ---------------------------------------------------------------------------
module gframe() { translate(G0) rotate([tilt, 0, 0]) children(); }

// glass outline grown by o (negative: shrunk), glass frame, 2D
module outline(o) {
    translate([-o, -o]) offset(r = glass_r + o) offset(delta = -(glass_r + o))
        square([glass_w + 2 * o, glass_d + 2 * o]);
}
// plan outline of the walls: projection of the rim's outer face at the ledge
// plane, stretched forward to the rim's top front edge
module plan2d() {
    hull() for (dy = [0, -rim_lean])
        translate([G0[0], G0[1] - w_j * st + dy]) scale([1, ct]) outline(rim_out);
}
module plan_prism(z0 = 0, h = 300) { translate([0, 0, z0]) linear_extrude(h) plan2d(); }

module below_ledge() { gframe() translate([-100, -100, w_j - 400]) cube([400, 400, 400]); }

// ---------------------------------------------------------------------------
// Rails: one under each display bracket, from the side wall; underside at 45
// degrees so that the body prints without supports.
module rail(b) {
    left = b[0] < glass_w / 2;
    x_in = gx(b[0] + (left ? rail_past : -rail_past));
    z_top = gz(b[1] - rail_half, -bracket_face) - pad_t;   // lowest point of the pad's underside
    intersection() {
        gframe() translate([left ? -rim_out - 2 : b[0] - rail_past, b[1] - rail_half, -bracket_face - 100])
            cube([left ? b[0] + rail_past + rim_out + 2 : glass_w + rim_out + 2 - (b[0] - rail_past), 2 * rail_half, 100]);
        translate([0, 300, 0]) rotate([90, 0, 0]) linear_extrude(400)
            polygon(left ? [[-10, z_top - x_in - 10], [x_in, z_top], [x_in, 400], [-10, 400]]
                         : [[body_w + 10, z_top - (body_w + 10 - x_in)], [x_in, z_top], [x_in, 400], [body_w + 10, 400]]);
        plan_prism(tray_t);
    }
}
module rail_holes(b) {
    // counterbore only through the rail (a longer one would cut the back wall)
    gframe() translate([b[0], b[1], -bracket_face - 25]) {
        cylinder(d = m25_clear, h = 26);
        cylinder(d = 5.5, h = 25 - pad_t);       // head and hex key access from below
    }
}

// Tray screw bosses (M3 inserts from below): two back corners, two front
// corners, two at the front either side of the middle (each tray half gets three).
tray_screws = [[9, 9], [body_w - 9, 9], [9, body_d - 9], [body_w - 9, body_d - 9],
               [mid - 15, wall + 4], [mid + 15, wall + 4]];
module tray_bosses() {
    intersection() {
        // a block around each insert, reaching the nearest front/back wall
        // (and the side wall in the corners)
        for (p = tray_screws) {
            x0 = p[0] < 20 ? 0 : p[0] > body_w - 20 ? p[0] - 6 : p[0] - 6;
            x1 = p[0] < 20 ? p[0] + 6 : p[0] > body_w - 20 ? body_w : p[0] + 6;
            y0 = p[1] < body_d / 2 ? 0 : p[1] - 6;
            y1 = p[1] < body_d / 2 ? p[1] + 6 : body_d;
            translate([x0, y0, tray_t]) cube([x1 - x0, y1 - y0, insert_len + 5]);
        }
        plan_prism(tray_t);
    }
}

// Bosses for the tongue (horizontal M3 inserts in the front wall)
module tongue_bosses() {
    for (x = [mid - 25, mid + 25]) translate([x - 5, 0, tray_t]) cube([10, wall + 7, 16 - tray_t]);
}

// Joint blocks for the split body: on the front and back walls, across the cut.
joints = [[wall, 18], [body_d - wall - 9, 40]];   // [y of the block's wall side, z bottom]
joint_half = 9;         // block width either side of the cut
module joint_blocks(which) { // "left" or "right"
    for (j = joints) {
        y0 = j[0] == wall ? wall - 1 : j[0];
        x0 = which == "left" ? mid - joint_half : mid;
        hull() {
            translate([x0, y0, j[1]]) cube([joint_half, 10, 14]);
            // 45 degree underside towards the wall
            translate([x0, j[0] == wall ? wall - 1 : body_d - wall - 1, j[1] - 9]) cube([joint_half, 2, 1]);
        }
    }
}
module joint_holes(which) {
    for (j = joints) {
        y = j[0] == wall ? wall + 4.5 : body_d - wall - 4.5;
        z = j[1] + 7;
        if (which == "left") {
            translate([mid - joint_half - 1, y, z]) rotate([0, 90, 0]) cylinder(d = m3_clear, h = joint_half + 2);
            translate([mid - joint_half - 1, y, z]) rotate([0, 90, 0]) cylinder(d = 6.5, h = joint_half - 2); // head, 3 mm clamp
        } else {
            translate([mid - 0.01, y, z]) rotate([0, 90, 0]) cylinder(d = insert_d, h = insert_len + 1);
        }
    }
}

module body_solid(which) {
    union() {
        // walls
        difference() {
            intersection() { plan_prism(tray_t); below_ledge(); }
            translate([0, 0, -1]) linear_extrude(400) offset(delta = -wall) plan2d();
        }
        // ledge under the glass
        intersection() {
            gframe() translate([0, 0, w_j - ledge_t]) linear_extrude(ledge_t)
                difference() { outline(rim_out); outline(-ledge_w); }
            plan_prism(tray_t);
        }
        // rim around the glass, its outer faces flush with the vertical walls
        intersection() {
            gframe() translate([0, 0, w_j]) linear_extrude(rim_above - w_j)
                difference() { outline(rim_out + 3); outline(glass_clear); }
            plan_prism(tray_t);
        }
        for (b = brackets) rail(b);
        tray_bosses();
        tongue_bosses();
        if (which != "all") joint_blocks(which);
    }
}

module body_holes(which) {
    for (b = brackets) rail_holes(b);
    // tray screw inserts (vertical, from below)
    for (p = tray_screws) translate([p[0], p[1], tray_t - 0.01]) cylinder(d = insert_d, h = insert_len + 1);
    // tongue inserts (front wall, horizontal)
    for (x = [mid - 25, mid + 25]) translate([x, -1, 8]) rotate([-90, 0, 0]) cylinder(d = insert_d, h = wall + insert_len);
    // port slots in the back wall, open at the bottom (the tray lowers the board out)
    for (p = ports) translate([bx2x(p[0]) - p[1] / 2, body_d - wall - 2, tray_t - 1])
        cube([p[1], wall + 4, pcb_top + p[3] + p[2] - tray_t + 1]);
    // microSD: pocket from the inside, leaving a thin skin in the back wall
    translate([bx2x(sd_slot[0]) - sd_slot[1] / 2, body_d - wall - 2, tray_t - 1])
        cube([sd_slot[1] + 1, wall + 2 - sd_skin, pcb_top + sd_slot[3] + sd_slot[2] - tray_t + 1]);
    // SW1 pin hole in the front wall, in line with the board's button
    translate([bx2x(sw1[0]), -1, pcb_top + sw1_h]) rotate([-90, 0, 0]) cylinder(d = 4.4, h = wall + 2);
    // external power button, left wall
    if (button_d > 0) translate([-1, button_y, button_z]) rotate([0, 90, 0]) cylinder(d = button_d, h = wall + 2);
    // fan grille (vertical slots inside a circle) and screw holes, back wall
    translate([fan_x, body_d + 1, fan_z]) rotate([90, 0, 0]) {
        intersection() {
            cylinder(d = 37, h = wall + 2);
            for (i = [-3 : 3]) translate([i * 5 - 1.25, -20, 0]) cube([2.5, 40, wall + 2]);
        }
        if (fan > 0) for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * fan_holes / 2, sy * fan_holes / 2, 0]) cylinder(d = m3_clear, h = wall + 2);
    }
    // low intake slots in both side walls, at the front; lower towards the back,
    // under the display rails
    for (x = [-1, body_w - wall - 1], i = [0 : 3])
        translate([x, 14 + i * 8, tray_t + 6]) cube([wall + 2, 3.5, intake_h[i]]);
    if (which != "all") joint_holes(which);
}

module body_part(which) { // "all", "left", "right"
    intersection() {
        difference() { body_solid(which); body_holes(which); }
        if (which == "left") translate([-50, -50, -50]) cube([mid + 50, 400, 400]);
        else if (which == "right") translate([mid, -50, -50]) cube([body_w, 400, 400]);
        else translate([-50, -50, -50]) cube([400, 400, 400]);
    }
}

// ---------------------------------------------------------------------------
// Tray: the bottom, carrying the board. Screws from below into the body's
// bosses; split at the middle for 180 mm beds, the halves joined by two splice
// plates in pockets underneath (M3 x 8 screws, nuts on top).
splices = [[mid, 12], [mid, by2y(15)]];       // [x, y] centres: front strip, under the board's back part
splice_l = 22; splice_w = 14; splice_t = 1.6;
module tray_part(which) {
    split = which != "all";
    intersection() {
        difference() {
            union() {
                linear_extrude(tray_t) plan2d();
                for (h = board_holes) translate([bx2x(h[0]), by2y(h[1]), 0]) cylinder(d = 6, h = pcb_z);
            }
            // board screw holes (M2.5, self-tapping into the standoffs)
            for (h = board_holes) translate([bx2x(h[0]), by2y(h[1]), 1]) cylinder(d = 2.2, h = pcb_z);
            // body screws, countersunk from below
            for (p = tray_screws) translate([p[0], p[1], -0.01]) {
                cylinder(d = m3_clear, h = tray_t + 1);
                cylinder(d1 = 6.6, d2 = m3_clear, h = 1.6);
            }
            // floor vents under the board (intake; the fan pulls air out at the back)
            for (i = [0 : 11]) let(x = board_x0 + 12 + i * 12.5) if (abs(x - mid) > 10)
                translate([x, by2y(70), -1]) hull() { cylinder(d = 4, h = tray_t + 2); translate([0, 45, 0]) cylinder(d = 4, h = tray_t + 2); }
            // rubber feet recesses (10 mm, 1 mm deep)
            for (x = [24, body_w - 24], y = [20, body_d - 20]) translate([x, y, -0.01]) cylinder(d = 10.4, h = 1);
            if (split) for (s = splices) {
                translate([s[0] - splice_l / 2 - 0.2, s[1] - splice_w / 2 - 0.2, -0.01]) cube([splice_l + 0.4, splice_w + 0.4, splice_t]);
                for (sx = [-1, 1]) translate([s[0] + sx * 6, s[1], -1]) cylinder(d = m3_clear, h = tray_t + 2);
            }
        }
        if (which == "left") translate([-50, -50, -50]) cube([mid + 50, 400, 400]);
        else if (which == "right") translate([mid, -50, -50]) cube([body_w, 400, 400]);
        else translate([-50, -50, -50]) cube([400, 400, 400]);
    }
}
module tray_splice() {
    difference() {
        cube([splice_l, splice_w, splice_t]);
        for (sx = [-1, 1]) translate([splice_l / 2 + sx * 6, splice_w / 2, -1]) cylinder(d = m3_clear, h = splice_t + 2);
    }
}

// ---------------------------------------------------------------------------
// Tongue: flat plate under the controller + a thicker part across the RCA gap +
// a vertical flange screwed to the body's front wall (2 x M3 into inserts).
module tongue() {
    total = tongue_under + rca_gap;
    difference() {
        union() {
            translate([-tongue_w / 2, 0, 0]) rounded_box([tongue_w, tongue_under + 5, tongue_t], 6);
            hull() {
                translate([-tongue_w / 2, tongue_under, 0]) cube([tongue_w, 1, tongue_gap_t]);
                translate([-35, total - 1, 0]) cube([70, 1, tongue_gap_t]);
            }
            translate([-35, total - wall - 1, 0]) cube([70, wall + 1, 16]);
        }
        for (x = [-25, 25]) translate([x, total - wall - 2, 8]) rotate([-90, 0, 0]) cylinder(d = m3_clear, h = wall + 4);
    }
}
module rounded_box(size, r) {
    hull() for (x = [r, size[0] - r], y = [r, size[1] - r])
        translate([x, y, 0]) cylinder(r = r, h = size[2]);
}

// SW1 pin: pushes the board's right-angle power button through the front wall
// (fallback for the external button). Shaft through the wall, head outside.
module sw1_pin() {
    cylinder(d = 7, h = 1.6);
    cylinder(d = 4, h = 1.6 + wall + (by2y(pcb_d) - wall) - 1.5);
}

// ---------------------------------------------------------------------------
// Test prints
// template_rim: the glass pocket (ledge + rim) as a flat ring; the glass must
// drop in with a little play and sit 0.5 mm below the rim. Needs a 200+ mm bed.
module template_rim() {
    linear_extrude(ledge_t) difference() { outline(rim_out); outline(-ledge_w); }
    translate([0, 0, ledge_t]) linear_extrude(rim_above - w_j) difference() { outline(rim_out); outline(glass_clear); }
}
module template_board() {
    difference() {
        cube([pcb_w - 10, pcb_d - 4, 1.6]);
        for (h = board_holes) translate([h[0] - 3, h[1] - 2, -1]) cylinder(d = m25_clear, h = 4);
        translate([20, 18, -1]) cube([pcb_w - 50, pcb_d - 40, 4]);
    }
}
module template_display() {
    difference() {
        cube([disp_holes_dx + 14, disp_holes_dy + 14, 1.6]);
        for (x = [7, 7 + disp_holes_dx], y = [7, 7 + disp_holes_dy]) translate([x, y, -1]) cylinder(d = m25_clear, h = 4);
        translate([20, 15, -1]) cube([disp_holes_dx - 26, disp_holes_dy - 16, 4]);
    }
}

// ---------------------------------------------------------------------------
module display_dummy() { // for the preview only
    gframe() {
        color("black", 0.9) translate([0, 0, -glass_t]) linear_extrude(glass_t) outline(0);
        color("gray", 0.9) translate([metal_left, metal_front, -bracket_face]) cube([metal_w, metal_d, bracket_face - glass_t]);
    }
}
module board_dummy() {
    color("green", 0.8) translate([board_x0, by2y(pcb_d), pcb_z]) cube([pcb_w, pcb_d, pcb_t]);
}

module assembly() {
    color("dimgray") body_part("all");
    color("silver") tray_part("all");
    board_dummy();
    display_dummy();
    color("orange") translate([mid, -(tongue_under + rca_gap), 0]) tongue();
}

if (part == "assembly") assembly();
else if (part == "body") body_part("all");
else if (part == "body_left") body_part("left");
else if (part == "body_right") body_part("right");
else if (part == "tray") tray_part("all");
else if (part == "tray_left") tray_part("left");
else if (part == "tray_right") tray_part("right");
else if (part == "tray_splice") tray_splice();
else if (part == "tongue") tongue();
else if (part == "sw1_pin") sw1_pin();
else if (part == "template_rim") template_rim();
else if (part == "template_board") template_board();
else if (part == "template_display") template_display();
