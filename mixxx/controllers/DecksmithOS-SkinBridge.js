// DecksmithOS skin bridge: on-screen buttons of the "DecksmithOS Standalone"
// skin that need more than a skin can do (a skin button can only toggle or
// push a control, not set a value, call engine.brake() or run a timer).
//
// Runs in the same virtual MIDI mapping as the Auto DJ script (snd-virmidi,
// DecksmithOS-AutoDJ.midi.xml), so it needs no Mixxx patch and nothing
// controller-specific. The skin's buttons push [Skin],dsm_* controls (1 while
// held, 0 on release); this script watches them. The skin creates those
// controls while it loads, which can be after this script starts, so each
// missing control is retried every second (up to two minutes).
//
//   [Skin],dsm_nav_source     library page, Sources (console music, USB)
//   [Skin],dsm_nav_playlist   library page, Playlists
//   [Skin],dsm_nav_browse     library page as it was left
//   [Skin],dsm_nav_taglist    library page, Auto DJ (the queue)
//   [Skin],dsm_nav_search     library page, Tracks (all music), focus on
//                             the search box
//   The sections are opened with [Library],show_<key> (Mixxx patch 0015).
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
DecksmithSkin.NAV = ["search", "source", "playlist", "taglist", "browse"];
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

// Connects a [Skin] control, or keeps it for a later retry while the skin is
// still being built (the skin creates its controls as it parses its files).
DecksmithSkin.watch = function(key, callback) {
    var c = engine.makeConnection("[Skin]", key, callback);
    if (c === undefined || !c.isConnected) {
        this.pending.push({key: key, callback: callback});
        return;
    }
    this.connections.push(c);
};

DecksmithSkin.connectAll = function() {
    this.pending = [];
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
    this.retryPending();
};

DecksmithSkin.retryPending = function() {
    if (this.pending.length === 0) {
        return;
    }
    if (++this.tries > this.RETRY_MAX) {
        print("DecksmithOS skin bridge: skin controls not found (" +
              this.pending.map(function(p) { return p.key; }).join(", ") +
              "); is the DecksmithOS Standalone skin loaded?");
        return;
    }
    engine.beginTimer(this.RETRY_MS, function() {
        var waiting = DecksmithSkin.pending;
        DecksmithSkin.pending = [];
        waiting.forEach(function(p) {
            DecksmithSkin.watch(p.key, p.callback);
        });
        DecksmithSkin.retryPending();
    }, true);
};

// --- Navigation --------------------------------------------------------------

// Library sections by key ([Library],show_<key>, Mixxx patch 0015)
DecksmithSkin.SECTION = {
    source: "computer",
    playlist: "playlist",
    taglist: "autodj",
    search: "tracks",
};

DecksmithSkin.navigate = function(name) {
    engine.setValue("[Skin]", "show_maximized_library", 1);
    var section = this.SECTION[name];
    if (section === undefined) {
        return; // BROWSE: the library page as it was left
    }
    if (name !== "search") {
        // the section's lists (CONSOLE / USB, playlists) are in the sidebar
        engine.setValue("[Sidebar]", "sidebar_visible", 1);
    }
    engine.setValue("[Library]", "show_" + section, 1);
    engine.setValue("[Library]", "show_" + section, 0);
    if (name === "search") {
        // after the view switch has been handled
        engine.beginTimer(100, function() {
            engine.setValue("[Library]", "focused_widget", 1); // search box
        }, true);
    }
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
