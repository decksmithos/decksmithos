// DecksmithOS Auto DJ transitions (AGENTS.md #31, stage 3).
//
// A controller script without controls: Mixxx runs it for a virtual MIDI
// device (ALSA snd-virmidi). Mixxx's own Auto DJ keeps doing the queue, the
// track loading and the crossfader; this script chooses the kind of each
// transition and plays it, between decks 1 and 2.
//
// Transitions (the usual DJ ones; their names are the MENU page buttons):
//   blend   32 beats together, the bass swapped when the crossfader passes
//           the middle (EQ)
//   filter  16 beats: the incoming track comes in through a high-pass
//           filter that opens, the outgoing one goes out through a closing
//           low-pass (the decks' quick effect, a filter by default)
//   echo    echo on the outgoing track from a beat before; at the start its
//           fader goes down and the echo tail plays over the incoming track
//   reverb  the same with a reverb wash
//   cut     straight to the incoming track on the phrase start
//   loop    the outgoing track rolls a loop of 4, 2, 1 and 1/2 beats over
//           the last 8 beats, then the cut
//   riser   high-pass sweep up on the outgoing track over the last 16 beats,
//           then the cut
//   brake   vinyl brake or backspin of the outgoing track, then the cut
//
// Choosing ([Skin],dsm_adj_mode, MENU page): SMART weighs the transitions
// that suit the two tracks: blend and filter only when the tempos can be
// matched (within 8 %, half/double tempo counts) and the keys fit (Camelot
// wheel: blend at most one step, filter at most three), loop and riser only
// when the tempos can be matched, echo/reverb/cut/brake always (more likely
// when the tempos are far apart); brake at most once in 8 transitions, and
// never the same transition twice in a row. RANDOM picks any allowed
// transition with the same tempo rules. Each transition can be switched off
// ([Skin],dsm_adj_use_<name>); with none left Mixxx's own crossfade plays.
//
// Timing (Mixxx patch 0021): the chosen length goes to
// [AutoDJ],next_transition_beats when the next track is loaded; with
// [AutoDJ],phrase_align the transition starts on a phrase start of the
// outgoing track and the incoming one starts on a phrase start.
// [AutoDJ],seconds_to_transition tells when to start what comes before
// (echo, loop, riser, brake). Loop and brake stop the outgoing track from
// reaching that point, so they cut with [AutoDJ],fade_now.
//
// For every transition: if the tempos can be matched, the incoming track
// takes the playing track's tempo and phase, with keylock, and afterwards
// slowly returns to its own tempo. The outgoing deck gets its EQ, filter,
// fader, tempo and keylock back when it stops.
//
// Nothing happens while Auto DJ is off, or on a deck with sync lock on (the
// DJ's choice). Times and limits are in CONFIG; they are judged by listening.

var DecksmithAutoDJ = {};

DecksmithAutoDJ.CONFIG = {
    // Largest tempo change (percent) the incoming track is matched over.
    maxTempoChangePercent: 8.0,
    // Seconds the incoming deck takes to return to its own tempo after the
    // transition (0: stay at the matched tempo).
    tempoReturnSeconds: 30,
    // Bass swap ramp in milliseconds.
    bassSwapMs: 400,
    // Keylock on the incoming deck while its tempo is not its own.
    useKeylock: true,
    // At most one brake in this many transitions
    brakeEvery: 8,
    // Effect unit for echo and reverb (effect 1: Echo, effect 2: Reverb;
    // loaded by decksmithos-mixxx-autoconf). Unit 1 is the BEAT FX of the
    // skin and unit 2 that of 4-deck layouts.
    fxUnit: "[EffectRack1_EffectUnit4]",
};

// beats: transition length (0: cut); pre: beats before the transition start
// where its first part begins; match: needs matched tempos; keys: largest
// Camelot distance (undefined: any); weight: SMART weight when the tempos
// match / when they do not.
DecksmithAutoDJ.TRANSITIONS = {
    blend: {beats: 32, pre: 0, match: true, keys: 1, weight: [6, 0]},
    filter: {beats: 16, pre: 0, match: true, keys: 3, weight: [3, 0]},
    echo: {beats: 8, pre: 1, match: false, weight: [2, 4]},
    reverb: {beats: 8, pre: 1, match: false, weight: [1, 2]},
    cut: {beats: 0, pre: 0, match: false, weight: [2, 3]},
    loop: {beats: 0, pre: 8, match: true, weight: [2, 0]},
    riser: {beats: 0, pre: 16, match: true, weight: [2, 0]},
    brake: {beats: 0, pre: 4, match: false, weight: [0.5, 1]},
};

DecksmithAutoDJ.DECKS = ["[Channel1]", "[Channel2]"];
DecksmithAutoDJ.STEP_MS = 50;

DecksmithAutoDJ.init = function(id, debugging) {
    this.debugging = debugging;
    this.connections = [];
    // per deck: saved values (or undefined) and timers
    this.state = {};
    this.DECKS.forEach(function(group) {
        DecksmithAutoDJ.state[group] = {
            savedLow: undefined,
            savedFilter: undefined,
            savedVolume: undefined,
            lowTimer: 0,
            filterTimer: 0,
            volumeTimer: 0,
            rateTimer: 0,
            keylockSet: false,
        };
        DecksmithAutoDJ.connections.push(
            engine.makeConnection(group, "play", function(value) {
                DecksmithAutoDJ.onPlay(group, value);
            }));
        DecksmithAutoDJ.connections.push(
            engine.makeConnection(group, "track_loaded", function(value) {
                if (value > 0) {
                    DecksmithAutoDJ.onTrackLoaded(group);
                }
            }));
        // a track loaded before it was analyzed gets its tempo and key later
        ["file_bpm", "key"].forEach(function(key) {
            DecksmithAutoDJ.connections.push(
                engine.makeConnection(group, key, function() {
                    DecksmithAutoDJ.onAnalysis(group);
                }));
        });
    });
    this.connections.push(engine.makeConnection("[Master]", "crossfader",
        function(value) {
            DecksmithAutoDJ.onCrossfader(value);
        }));
    this.connections.push(engine.makeConnection("[AutoDJ]", "enabled",
        function(value) {
            if (!value) {
                DecksmithAutoDJ.reset();
            }
        }));
    var countdown = engine.makeConnection("[AutoDJ]", "seconds_to_transition",
        function(value) {
            DecksmithAutoDJ.onCountdown(value);
        });
    if (countdown) {
        this.connections.push(countdown);
    } else {
        this.log("[AutoDJ],seconds_to_transition missing (Mixxx without patch 0021): " +
                 "only Mixxx's own crossfade timing");
    }
    // the plan for the next transition: {from, to, name, matched}
    this.plan = null;
    // {from, to, name, swapped, ...} while a transition runs
    this.transition = null;
    this.history = [];
    this.timers = {};
    this.log("ready");
    // Reloaded while Auto DJ runs (a controller plugged in sets up the
    // controllers again): plan the next transition again
    this.startTimer("resume", 1000, function() {
        DecksmithAutoDJ.DECKS.forEach(function(group) {
            if (!DecksmithAutoDJ.plan && engine.getValue(group, "track_loaded") > 0 &&
                    !engine.getValue(group, "play")) {
                DecksmithAutoDJ.onTrackLoaded(group);
            }
        });
    }, true);
};

DecksmithAutoDJ.shutdown = function() {
    this.reset();
    this.connections.forEach(function(c) {
        c.disconnect();
    });
};

DecksmithAutoDJ.log = function(message) {
    print("DecksmithOS Auto DJ: " + message);
};

DecksmithAutoDJ.other = function(group) {
    return group === this.DECKS[0] ? this.DECKS[1] : this.DECKS[0];
};

DecksmithAutoDJ.deckNumber = function(group) {
    return group === this.DECKS[0] ? 1 : 2;
};

DecksmithAutoDJ.eqGroup = function(group) {
    return "[EqualizerRack1_" + group + "_Effect1]";
};

DecksmithAutoDJ.filterGroup = function(group) {
    return "[QuickEffectRack1_" + group + "]";
};

DecksmithAutoDJ.synced = function(group) {
    return engine.getValue(group, "sync_enabled") > 0;
};

DecksmithAutoDJ.beatMs = function(group) {
    var bpm = engine.getValue(group, "bpm");
    return bpm > 0 ? 60000 / bpm : 500;
};

DecksmithAutoDJ.startTimer = function(name, ms, callback, oneShot) {
    this.stopTimer(name);
    this.timers[name] = engine.beginTimer(Math.max(20, Math.round(ms)), function() {
        if (oneShot) {
            delete DecksmithAutoDJ.timers[name];
        }
        callback();
    }, oneShot);
};

DecksmithAutoDJ.stopTimer = function(name) {
    if (this.timers[name]) {
        engine.stopTimer(this.timers[name]);
        delete this.timers[name];
    }
};

// --- Choosing -----------------------------------------------------------------

// Tempo change in percent from bpm "from" to bpm "to", with half/double tempo
// counted as the same (as in Mixxx's sync); null if a tempo is unknown.
DecksmithAutoDJ.tempoChangePercent = function(from, to) {
    if (!(from > 0) || !(to > 0)) {
        return null;
    }
    var best = to / from;
    [0.5, 2.0].forEach(function(factor) {
        var ratio = to * factor / from;
        if (Math.abs(Math.log(ratio)) < Math.abs(Math.log(best))) {
            best = ratio;
        }
    });
    return (best - 1) * 100;
};

// Camelot wheel position of a Mixxx key ([ChannelN],key: 1-12 C..B major,
// 13-24 C..B minor) as {number, minor}, or null
DecksmithAutoDJ.MAJOR = [8, 3, 10, 5, 12, 7, 2, 9, 4, 11, 6, 1];
DecksmithAutoDJ.MINOR = [5, 12, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10];
DecksmithAutoDJ.camelot = function(key) {
    key = Math.round(key);
    if (key >= 1 && key <= 12) {
        return {number: this.MAJOR[key - 1], minor: false};
    }
    if (key >= 13 && key <= 24) {
        return {number: this.MINOR[key - 13], minor: true};
    }
    return null;
};

// Steps between two keys on the Camelot wheel (relative major/minor: 1),
// null if a key is unknown
DecksmithAutoDJ.keyDistance = function(a, b) {
    var ka = this.camelot(a);
    var kb = this.camelot(b);
    if (!ka || !kb) {
        return null;
    }
    var d = Math.abs(ka.number - kb.number);
    d = Math.min(d, 12 - d);
    return d + (ka.minor === kb.minor ? 0 : 1);
};

DecksmithAutoDJ.allowed = function(name) {
    // switched on unless the skin says otherwise (no skin: all on)
    return engine.getValue("[Skin]", "dsm_adj_use_" + name) !== 0;
};

DecksmithAutoDJ.choose = function(from, to) {
    var change = this.tempoChangePercent(
        engine.getValue(from, "bpm"), engine.getValue(to, "file_bpm"));
    var matched = change !== null && !this.synced(from) && !this.synced(to) &&
        Math.abs(change) <= this.CONFIG.maxTempoChangePercent;
    var keys = this.keyDistance(engine.getValue(from, "key"), engine.getValue(to, "key"));
    var smart = engine.getValue("[Skin]", "dsm_adj_mode") === 0;
    var last = this.history.length ? this.history[this.history.length - 1] : null;
    var recentBrake = this.history.slice(-(this.CONFIG.brakeEvery - 1)).indexOf("brake") >= 0;
    var candidates = [];
    var total = 0;
    Object.keys(this.TRANSITIONS).forEach(function(name) {
        var t = DecksmithAutoDJ.TRANSITIONS[name];
        if (!DecksmithAutoDJ.allowed(name) || (t.match && !matched)) {
            return;
        }
        if (name === "brake" && recentBrake) {
            return;
        }
        var weight = 1;
        if (smart) {
            if (t.keys !== undefined && keys !== null && keys > t.keys) {
                return;
            }
            weight = t.weight[matched ? 0 : 1];
        }
        if (weight > 0) {
            candidates.push({name: name, weight: weight});
            total += weight;
        }
    });
    if (candidates.length > 1 && last !== null) {
        candidates = candidates.filter(function(c) {
            if (c.name === last) {
                total -= c.weight;
                return false;
            }
            return true;
        });
    }
    var name = null;
    var r = Math.random() * total;
    for (var i = 0; i < candidates.length; i++) {
        r -= candidates[i].weight;
        if (r < 0 || i === candidates.length - 1) {
            name = candidates[i].name;
            break;
        }
    }
    return {name: name, matched: matched, change: change, keys: keys};
};

// The next track is loaded on "group" while the other deck plays: plan the
// transition and tell Auto DJ its length
DecksmithAutoDJ.onTrackLoaded = function(group) {
    var from = this.other(group);
    if (!engine.getValue("[AutoDJ]", "enabled") || !engine.getValue(from, "play") ||
            this.transition) {
        return;
    }
    var c = this.choose(from, group);
    this.plan = {from: from, to: group, name: c.name, matched: c.matched, pre: false,
        complete: c.change !== null && c.keys !== null};
    engine.setValue("[AutoDJ]", "next_transition_beats",
        c.name ? this.TRANSITIONS[c.name].beats : -1);
    this.log("next: " + (c.name || "Mixxx crossfade (no transition allowed)") +
             " (tempo " + (c.change === null ? "?" : c.change.toFixed(1) + " %") +
             ", key steps " + (c.keys === null ? "?" : c.keys) + ")");
};

// The tempo or key of a deck changed (its analysis finished): choose again if
// the plan was made without them and has not started yet
DecksmithAutoDJ.onAnalysis = function(group) {
    var p = this.plan;
    if (!p || p.complete || p.pre || this.transition ||
            (group !== p.from && group !== p.to)) {
        return;
    }
    // tempo and key arrive one after the other
    this.startTimer("replan", 500, function() {
        var q = DecksmithAutoDJ.plan;
        if (q && !q.complete && !q.pre && !DecksmithAutoDJ.transition) {
            DecksmithAutoDJ.onTrackLoaded(q.to);
        }
    }, true);
};

// --- Before the transition ------------------------------------------------------

DecksmithAutoDJ.onCountdown = function(seconds) {
    var p = this.plan;
    if (!p || p.pre || !p.name || seconds <= 0 || this.transition) {
        return;
    }
    var pre = this.TRANSITIONS[p.name].pre;
    if (pre <= 0 || seconds * 1000 > pre * this.beatMs(p.from)) {
        return;
    }
    p.pre = true;
    var beatMs = this.beatMs(p.from);
    switch (p.name) {
    case "echo":
    case "reverb":
        this.fxOn(p.from, p.name === "echo" ? 1 : 2);
        break;
    case "riser":
        this.rampFilter(p.from, 0.9, seconds * 1000);
        break;
    case "loop":
        this.loopRoll(p.from, beatMs);
        break;
    case "brake":
        this.brake(p.from);
        break;
    }
};

// Echo or reverb (effect slot 1 or 2 of the Auto DJ unit) on a deck
DecksmithAutoDJ.fxOn = function(group, slot) {
    var unit = this.CONFIG.fxUnit;
    var effect = unit.replace("]", "_Effect" + slot + "]");
    if (!engine.getValue(effect, "loaded")) {
        this.log(effect + " has no effect loaded: no " + (slot === 1 ? "echo" : "reverb"));
        return;
    }
    engine.setValue(unit, "group_" + group + "_enable", 1);
    engine.setValue(effect, "enabled", 1);
    engine.setValue(unit, "mix", 1);
    engine.setValue(unit, "enabled", 1);
    this.fx = {group: group, effect: effect};
};

DecksmithAutoDJ.fxOff = function() {
    if (!this.fx) {
        return;
    }
    engine.setValue(this.fx.effect, "enabled", 0);
    engine.setValue(this.CONFIG.fxUnit, "group_" + this.fx.group + "_enable", 0);
    this.fx = null;
};

// Loop of 4 beats, then 2, 1 and 1/2 beats (8 beats in all), then the cut
DecksmithAutoDJ.LOOP_STEPS = [[4, 1], [2, 1], [1, 1], [0.5, 2]];
DecksmithAutoDJ.loopRoll = function(group, beatMs) {
    var step = 0;
    var next = function() {
        if (step >= DecksmithAutoDJ.LOOP_STEPS.length) {
            DecksmithAutoDJ.cutNow(group);
            return;
        }
        var s = DecksmithAutoDJ.LOOP_STEPS[step++];
        engine.setValue(group, "beatloop_size", s[0]);
        if (!engine.getValue(group, "loop_enabled")) {
            engine.setValue(group, "beatloop_activate", 1);
        }
        DecksmithAutoDJ.startTimer("loop", s[0] * s[1] * beatMs, next, true);
    };
    next();
};

DecksmithAutoDJ.brake = function(group) {
    var spin = Math.random() < 0.5;
    var deck = this.deckNumber(group);
    if (spin) {
        engine.spinback(deck, true, 1.5);
    } else {
        engine.brake(deck, true, 1.0);
    }
    this.log(spin ? "backspin" : "brake");
    // cut when the deck has (nearly) stopped turning
    var started = Date.now();
    this.startTimer("brake", 20, function() {
        var speed = Math.abs(engine.getValue(group, "scratch2"));
        if (speed < 0.15 || Date.now() - started > 4000 || !engine.getValue(group, "play")) {
            DecksmithAutoDJ.stopTimer("brake");
            DecksmithAutoDJ.cutNow(group);
        }
    }, false);
};

// Start the transition now, as a cut (loop roll and brake: the outgoing track
// does not reach the planned start)
DecksmithAutoDJ.cutNow = function(group) {
    if (engine.getValue(group, "loop_enabled")) {
        engine.setValue(group, "reloop_toggle", 1);
    }
    engine.setValue("[AutoDJ]", "next_transition_beats", 0);
    engine.setValue("[AutoDJ]", "fade_now", 1);
    engine.setValue("[AutoDJ]", "fade_now", 0);
};

// --- The transition -----------------------------------------------------------

DecksmithAutoDJ.onPlay = function(group, value) {
    if (!engine.getValue("[AutoDJ]", "enabled")) {
        return;
    }
    var other = this.other(group);
    if (value > 0 && engine.getValue(other, "play") > 0 && !this.transition) {
        this.startTransition(other, group);
    } else if (value === 0 && this.transition && this.transition.from === group) {
        this.endTransition();
    }
};

DecksmithAutoDJ.startTransition = function(from, to) {
    var p = this.plan && this.plan.from === from && this.plan.to === to ? this.plan : null;
    var name = p ? p.name : null;
    this.plan = null;
    this.transition = {from: from, to: to, name: name, swapped: false};
    if (name) {
        this.history.push(name);
        this.history = this.history.slice(-16);
    }
    // The outgoing deck stops returning to its own tempo: its tempo is the
    // one the incoming track follows now.
    this.stopRateTimer(from);

    var change = this.tempoChangePercent(
        engine.getValue(from, "bpm"), engine.getValue(to, "file_bpm"));
    if (this.synced(from) || this.synced(to)) {
        this.log("sync lock is on: tempo left to it");
    } else if (name === "brake") {
        this.log("brake: the incoming track keeps its own tempo");
    } else if (change === null) {
        this.log("tempo unknown: not matched");
    } else if (Math.abs(change) > this.CONFIG.maxTempoChangePercent) {
        this.log("tempo change " + change.toFixed(1) + " % too large: not matched");
    } else {
        this.stopRateTimer(to);
        if (this.CONFIG.useKeylock && !engine.getValue(to, "keylock")) {
            engine.setValue(to, "keylock", 1);
            this.state[to].keylockSet = true;
        }
        engine.setValue(to, "beatsync_tempo", 1);
        engine.setValue(to, "beatsync_phase", 1);
        this.log(from + " -> " + to + ": tempo matched (" + change.toFixed(1) + " %)");
    }
    this.log("transition: " + (name || "Mixxx crossfade"));

    var beatMs = this.beatMs(from);
    switch (name) {
    case null:
    case "blend":
        // Incoming bass out until the swap at the crossfader middle
        this.rampLow(to, 0);
        this.onCrossfader(engine.getValue("[Master]", "crossfader"));
        break;
    case "filter":
        this.transition.swapped = true; // the filters take care of the bass
        var ms = this.TRANSITIONS.filter.beats * beatMs;
        this.setFilter(to, 1.0);
        this.rampFilter(to, null, ms);
        this.rampFilter(from, 0.05, ms);
        break;
    case "echo":
    case "reverb":
        this.transition.swapped = true;
        if (!this.fx) {
            // started without the beat before (e.g. FADE NOW)
            this.fxOn(from, name === "echo" ? 1 : 2);
        }
        this.rampVolume(from, 0, beatMs);
        break;
    default:
        // cuts: nothing to blend
        this.transition.swapped = true;
        this.stopTimer("loop");
        this.stopTimer("brake");
        break;
    }
};

// Crossfader position normalized so that -1 is the left side.
DecksmithAutoDJ.crossfaderTowards = function(value, group) {
    if (engine.getValue("[Mixer Profile]", "xFaderReverse") > 0) {
        value = -value;
    }
    // orientation: 0 left, 1 center, 2 right
    var orientation = engine.getValue(group, "orientation");
    if (orientation === 0) {
        return -value;
    }
    if (orientation === 2) {
        return value;
    }
    return 0;
};

DecksmithAutoDJ.onCrossfader = function(value) {
    var t = this.transition;
    if (!t || t.swapped) {
        return;
    }
    if (this.crossfaderTowards(value, t.to) >= 0) {
        t.swapped = true;
        this.rampLow(t.from, 0);
        this.rampLow(t.to, null);
        this.log("bass swap");
    }
};

DecksmithAutoDJ.endTransition = function() {
    var t = this.transition;
    this.transition = null;
    this.stopTimer("loop");
    this.stopTimer("brake");
    this.fxOff();
    if (!t.swapped) {
        this.rampLow(t.to, null);
    }
    this.rampFilter(t.to, null, 0);
    // The outgoing deck is stopped: give it back its EQ, filter, fader, tempo
    // and keylock for the next track Auto DJ loads into it.
    this.restoreDeck(t.from);
    this.returnToOwnTempo(t.to);
};

// --- Ramps --------------------------------------------------------------------

// Ramp a deck parameter to "target", or back to the value it had before the
// script changed it (target null). key: the state fields' name.
DecksmithAutoDJ.ramp = function(group, key, get, set, target, ms) {
    var st = this.state[group];
    var saved = "saved" + key;
    var timer = key.charAt(0).toLowerCase() + key.slice(1) + "Timer";
    if (st[timer]) {
        engine.stopTimer(st[timer]);
        st[timer] = 0;
    }
    if (target === null) {
        if (st[saved] === undefined) {
            return;
        }
        target = st[saved];
        st[saved] = undefined;
    } else if (st[saved] === undefined) {
        st[saved] = get();
    }
    var start = get();
    var steps = Math.max(1, Math.round(ms / this.STEP_MS));
    if (ms <= 0) {
        set(target);
        return;
    }
    var step = 0;
    st[timer] = engine.beginTimer(this.STEP_MS, function() {
        step++;
        set(start + (target - start) * step / steps);
        if (step >= steps) {
            engine.stopTimer(st[timer]);
            st[timer] = 0;
        }
    });
};

// Low EQ (normalized 0..1)
DecksmithAutoDJ.rampLow = function(group, target) {
    var eq = this.eqGroup(group);
    this.ramp(group, "Low",
        function() { return engine.getParameter(eq, "parameter1"); },
        function(v) { engine.setParameter(eq, "parameter1", v); },
        target, this.CONFIG.bassSwapMs);
};

// Quick effect super knob (filter: 0 low-pass, 0.5 off, 1 high-pass)
DecksmithAutoDJ.rampFilter = function(group, target, ms) {
    var fx = this.filterGroup(group);
    this.ramp(group, "Filter",
        function() { return engine.getParameter(fx, "super1"); },
        function(v) { engine.setParameter(fx, "super1", v); },
        target, ms);
};

DecksmithAutoDJ.setFilter = function(group, value) {
    var st = this.state[group];
    var fx = this.filterGroup(group);
    if (st.savedFilter === undefined) {
        st.savedFilter = engine.getParameter(fx, "super1");
    }
    engine.setParameter(fx, "super1", value);
};

// Channel fader
DecksmithAutoDJ.rampVolume = function(group, target, ms) {
    this.ramp(group, "Volume",
        function() { return engine.getParameter(group, "volume"); },
        function(v) { engine.setParameter(group, "volume", v); },
        target, ms);
};

DecksmithAutoDJ.stopRateTimer = function(group) {
    var st = this.state[group];
    if (st.rateTimer) {
        engine.stopTimer(st.rateTimer);
        st.rateTimer = 0;
    }
};

DecksmithAutoDJ.releaseKeylock = function(group) {
    var st = this.state[group];
    if (st.keylockSet) {
        engine.setValue(group, "keylock", 0);
        st.keylockSet = false;
    }
};

DecksmithAutoDJ.returnToOwnTempo = function(group) {
    this.stopRateTimer(group);
    var start = engine.getValue(group, "rate");
    var seconds = this.CONFIG.tempoReturnSeconds;
    if (start === 0 || seconds <= 0 || this.synced(group)) {
        if (start === 0) {
            this.releaseKeylock(group);
        }
        return;
    }
    var steps = Math.max(1, Math.round(seconds * 1000 / 250));
    var step = 0;
    var st = this.state[group];
    st.rateTimer = engine.beginTimer(250, function() {
        step++;
        engine.setValue(group, "rate", start * (1 - step / steps));
        if (step >= steps) {
            engine.stopTimer(st.rateTimer);
            st.rateTimer = 0;
            DecksmithAutoDJ.releaseKeylock(group);
        }
    });
};

// EQ, filter and fader back as they were, ramps stopped
DecksmithAutoDJ.restoreMixer = function(group) {
    var st = this.state[group];
    ["lowTimer", "filterTimer", "volumeTimer"].forEach(function(timer) {
        if (st[timer]) {
            engine.stopTimer(st[timer]);
            st[timer] = 0;
        }
    });
    if (st.savedLow !== undefined) {
        engine.setParameter(this.eqGroup(group), "parameter1", st.savedLow);
        st.savedLow = undefined;
    }
    if (st.savedFilter !== undefined) {
        engine.setParameter(this.filterGroup(group), "super1", st.savedFilter);
        st.savedFilter = undefined;
    }
    if (st.savedVolume !== undefined) {
        engine.setParameter(group, "volume", st.savedVolume);
        st.savedVolume = undefined;
    }
};

DecksmithAutoDJ.restoreDeck = function(group) {
    this.stopRateTimer(group);
    this.restoreMixer(group);
    if (engine.getValue(group, "loop_enabled")) {
        engine.setValue(group, "reloop_toggle", 1);
    }
    if (!this.synced(group)) {
        engine.setValue(group, "rate", 0);
    }
    this.releaseKeylock(group);
};

// Auto DJ off (or the script stops): leave the decks as the DJ expects them.
// A playing deck keeps its tempo (no jump); only a running return continues
// no further.
DecksmithAutoDJ.reset = function() {
    this.transition = null;
    this.plan = null;
    Object.keys(this.timers).forEach(function(name) {
        DecksmithAutoDJ.stopTimer(name);
    });
    this.fxOff();
    this.DECKS.forEach(function(group) {
        DecksmithAutoDJ.stopRateTimer(group);
        DecksmithAutoDJ.restoreMixer(group);
        if (!engine.getValue(group, "play")) {
            DecksmithAutoDJ.restoreDeck(group);
        }
    });
};
