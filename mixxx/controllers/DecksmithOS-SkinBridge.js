// DecksmithOS skin bridge: on-screen buttons of the "DecksmithOS Standalone"
// skin that need more than a skin can do (a skin button can only toggle or
// push a control, not set a value, call engine.brake() or run a timer).
//
// Runs in the same virtual MIDI mapping as the Auto DJ script (snd-virmidi,
// DecksmithOS-AutoDJ.midi.xml), so it needs no Mixxx patch and nothing
// controller-specific. The skin's buttons push [Skin],dsm_* controls (1 while
// held, 0 on release); this script watches them. The skin creates those
// controls when it loads, which can be after this script starts, so the
// connections are retried until they exist.
//
//   [Skin],dsm_nav_search     library page, focus on the search box
//   [Skin],dsm_nav_source     library page, sidebar on Computer (folders, USB)
//   [Skin],dsm_nav_playlist   library page, sidebar on Playlists
//   [Skin],dsm_nav_taglist    library page, sidebar on Auto DJ (the queue)
//   [Skin],dsm_xpad_<n>       X-PAD: while held, the BEAT FX effect
//                             ([EffectRack1_EffectUnit1], focused effect or
//                             effect 1) is on with its time (parameter 1) at
//                             XPAD_BEATS[n-1] beats; restored on release
//   [Skin],dsm_rfx_<d>_<name> RELEASE FX on deck d (1, 2):
//       brake_s / brake_l     vinyl brake, short / long
//       spin_s / spin_l       backspin, short / long
//       mute                  silent while held
//       duck                  -12 dB while held
//       buildup               high-pass filter sweep while held (the deck's
//                             quick effect super knob), back on release

var DecksmithSkin = {};

DecksmithSkin.XPAD_BEATS = [1 / 32, 1 / 16, 1 / 8, 1 / 4, 1 / 2, 3 / 4, 1, 2];
DecksmithSkin.RFX = ["brake_s", "brake_l", "spin_s", "spin_l", "mute", "duck", "buildup"];
DecksmithSkin.NAV = ["search", "source", "playlist", "taglist"];
DecksmithSkin.DECKS = 2; // the skin has RELEASE FX pads for decks 1 and 2
DecksmithSkin.RETRY_MS = 1000;
DecksmithSkin.RETRY_MAX = 120;
DecksmithSkin.BUILDUP_MS = 8000; // full sweep time
DecksmithSkin.STEP_MS = 50;

DecksmithSkin.init = function() {
    this.connections = [];
    this.xpadSaved = null;
    this.held = {};       // per deck: saved values while a held effect is on
    this.timers = {};
    this.tries = 0;
    this.connectAll();
};

DecksmithSkin.shutdown = function() {
    Object.keys(this.timers).forEach(function(k) {
        engine.stopTimer(DecksmithSkin.timers[k]);
    });
    this.connections.forEach(function(c) {
        c.disconnect();
    });
};

DecksmithSkin.watch = function(key, callback) {
    var c = engine.makeConnection("[Skin]", key, callback);
    if (c === undefined || !c.isConnected) {
        return false;
    }
    this.connections.push(c);
    return true;
};

DecksmithSkin.connectAll = function() {
    // The skin's controls exist once the skin is loaded; probe one of them.
    var probe = engine.makeConnection("[Skin]", "dsm_nav_search", function() {});
    if (probe === undefined || !probe.isConnected) {
        if (++this.tries <= this.RETRY_MAX) {
            engine.beginTimer(this.RETRY_MS, function() {
                DecksmithSkin.connectAll();
            }, true);
        } else {
            print("DecksmithOS skin bridge: skin controls not found; is the skin loaded?");
        }
        return;
    }
    probe.disconnect();

    this.NAV.forEach(function(name) {
        DecksmithSkin.watch("dsm_nav_" + name, function(value) {
            if (value > 0) {
                DecksmithSkin.navigate(name);
            }
        });
    });
    this.XPAD_BEATS.forEach(function(beats, i) {
        DecksmithSkin.watch("dsm_xpad_" + (i + 1), function(value) {
            DecksmithSkin.xpad(beats, value > 0);
        });
    });
    for (var d = 1; d <= this.DECKS; d++) {
        this.RFX.forEach(function(name) {
            var deck = d;
            DecksmithSkin.watch("dsm_rfx_" + deck + "_" + name, function(value) {
                DecksmithSkin.releaseFx(deck, name, value > 0);
            });
        });
    }
};

// --- Navigation --------------------------------------------------------------

// Sidebar rows below the first one (Tracks), in Mixxx 2.5's order: Tracks,
// Auto DJ, Playlists, Crates, Computer, ...
DecksmithSkin.SIDEBAR_ROW = {source: 4, playlist: 2, taglist: 1};

DecksmithSkin.navigate = function(name) {
    engine.setValue("[Skin]", "show_maximized_library", 1);
    if (name === "search") {
        engine.setValue("[Library]", "focused_widget", 1); // search box
        return;
    }
    // SOURCE: Computer (folders, USB drives); PLAYLIST: Playlists;
    // TAG LIST: Auto DJ (the queue)
    engine.setValue("[Sidebar]", "sidebar_visible", 1);
    engine.setValue("[Library]", "focused_widget", 2); // sidebar
    var row = this.SIDEBAR_ROW[name];
    engine.beginTimer(100, function() {
        // In the sidebar MoveVertical moves one row per call, whatever the value
        for (var i = 0; i < 20; i++) {
            engine.setValue("[Library]", "MoveVertical", -1); // to the top
        }
        for (var j = 0; j < row; j++) {
            engine.setValue("[Library]", "MoveVertical", 1);
        }
        engine.setValue("[Library]", "GoToItem", 1);
    }, true);
};

// --- X-PAD -------------------------------------------------------------------

DecksmithSkin.beatFxGroup = function() {
    var focused = engine.getValue("[EffectRack1_EffectUnit1]", "focused_effect");
    return "[EffectRack1_EffectUnit1_Effect" + (focused > 0 ? focused : 1) + "]";
};

DecksmithSkin.xpad = function(beats, down) {
    if (down) {
        var group = this.beatFxGroup();
        if (this.xpadSaved === null) {
            this.xpadSaved = {
                group: group,
                enabled: engine.getValue(group, "enabled"),
                time: engine.getValue(group, "parameter1"),
            };
        }
        engine.setValue(this.xpadSaved.group, "parameter1", beats);
        engine.setValue(this.xpadSaved.group, "enabled", 1);
        this.xpadDown = (this.xpadDown || 0) + 1;
    } else if (this.xpadSaved !== null) {
        this.xpadDown = Math.max(0, (this.xpadDown || 1) - 1);
        if (this.xpadDown === 0) {
            var s = this.xpadSaved;
            engine.setValue(s.group, "parameter1", s.time);
            engine.setValue(s.group, "enabled", s.enabled);
            this.xpadSaved = null;
        }
    }
};

// --- RELEASE FX --------------------------------------------------------------

DecksmithSkin.releaseFx = function(deck, name, down) {
    var group = "[Channel" + deck + "]";
    var key = deck + "_" + name;
    switch (name) {
    case "brake_s":
    case "brake_l":
        if (down) {
            engine.brake(deck, true, name === "brake_s" ? 2.5 : 0.6);
        }
        break;
    case "spin_s":
    case "spin_l":
        if (down) {
            engine.spinback(deck, true, name === "spin_s" ? 2.0 : 0.8);
        }
        break;
    case "mute":
        engine.setValue(group, "mute", down ? 1 : 0);
        break;
    case "duck":
        if (down) {
            this.held[key] = engine.getValue(group, "pregain");
            engine.setValue(group, "pregain", this.held[key] * 0.25);
        } else if (this.held[key] !== undefined) {
            engine.setValue(group, "pregain", this.held[key]);
            delete this.held[key];
        }
        break;
    case "buildup":
        this.buildup(deck, down);
        break;
    }
};

DecksmithSkin.buildup = function(deck, down) {
    var fx = "[QuickEffectRack1_[Channel" + deck + "]]";
    var key = deck + "_buildup";
    if (this.timers[key]) {
        engine.stopTimer(this.timers[key]);
        delete this.timers[key];
    }
    if (down) {
        if (this.held[key] === undefined) {
            this.held[key] = engine.getParameter(fx, "super1");
        }
        var start = this.held[key];
        var steps = this.BUILDUP_MS / this.STEP_MS;
        var n = 0;
        this.timers[key] = engine.beginTimer(this.STEP_MS, function() {
            n = Math.min(n + 1, steps);
            // ease in: slow at first, faster towards the end
            var t = n / steps;
            engine.setParameter(fx, "super1", start + (0.95 - start) * t * t);
            if (n >= steps) {
                engine.stopTimer(DecksmithSkin.timers[key]);
                delete DecksmithSkin.timers[key];
            }
        });
    } else if (this.held[key] !== undefined) {
        engine.setParameter(fx, "super1", this.held[key]);
        delete this.held[key];
    }
};
