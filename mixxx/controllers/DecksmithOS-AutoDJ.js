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
//   echo    12 beats: the echo comes on and the incoming track starts
//           together; the outgoing fader goes down over 4 beats while the
//           echo fills, then its tail plays over the incoming track
//   reverb  the same with a reverb wash
//   fade    16 beats: the outgoing fader goes down while the incoming one
//           comes up, the bass swapped in the middle; any keys, and 8 beats
//           when the tempos cannot be matched (in place of a cut)
//   loop    the outgoing track rolls a loop of 4, 2, 1 and 1/2 beats over
//           8 beats, then leaves the loop and fades out over 8 beats while
//           the incoming one comes in (bass swapped in the middle)
//   riser   high-pass sweep up on the outgoing track over 16 beats, then it
//           fades out over 8 beats (still filtered, so the incoming track
//           comes in with its bass)
//   brake   vinyl brake of the outgoing track; nearly stopped, the incoming
//           one starts and comes up over 4 beats (its own fader)
//
// Choosing ([Skin],dsm_adj_mode, MENU page): SMART weighs the transitions
// that suit the two tracks: blend and filter only when the tempos can be
// matched (within 10 %, half/double tempo counts) and the keys fit (Camelot
// wheel: blend at most one step, filter at most three), loop and riser only
// when the tempos can be matched, echo/reverb/fade/brake always (more likely
// when the tempos are far apart); brake at most once in 8 transitions, and
// never the same transition twice in a row. RANDOM picks any allowed
// transition with the same tempo rules. Each transition can be switched off
// ([Skin],dsm_adj_use_<name>); with none left Mixxx's own crossfade plays.
//
// The planned transition is shown on the Auto DJ page ([Skin],dsm_adj_next:
// 0 none, else its place in TRANSITIONS + 1); a tap there picks the next
// allowed one that suits the tempos, until what comes before it has begun.
//
// Timing (Mixxx patch 0021): the chosen length goes to
// [AutoDJ],next_transition_beats when the next track is loaded; with
// [AutoDJ],phrase_align the transition starts on a phrase start of the
// outgoing track and the incoming one starts on a phrase start.
// [AutoDJ],seconds_to_transition tells when to start what comes before
// (echo, loop, riser, brake). Loop and brake stop the outgoing track from
// reaching that point, so they start the transition with [AutoDJ],fade_now
// (loop: its 8-beat fade; brake: a cut near the end of the brake, the
// incoming track coming up on its own fader).
//
// PLAY on the waiting deck (any controller) while Auto DJ runs and the
// skin's FADE NOW ([Skin],dsm_adj_fade_now) start the planned transition
// from the next beat, the same as it would come by itself: what comes before
// it first (riser 16 beats, loop roll and brake start it). Asked again
// meanwhile: at once. So does a controller's crossfader moved all the way
// to the waiting deck (Mixxx patch 0021: [AutoDJ],fade_by_script and
// fade_request; stock Mixxx makes a hard cut). Mixxx's own "Fade" button of
// the Auto DJ table is hidden by the skin.
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
    maxTempoChangePercent: 10.0,
    // A larger difference is closed by bringing the playing track towards
    // the next one first, by up to this much, gradually over the last
    // tempoLeadSeconds before the transition (keylock on)
    maxOutgoingTempoPercent: 6.0,
    tempoLeadSeconds: 60,
    // Seconds the incoming deck takes to return to its own tempo after the
    // transition (0: stay at the matched tempo).
    tempoReturnSeconds: 30,
    // Bass swap ramp in milliseconds.
    bassSwapMs: 400,
    // Keylock on the incoming deck while its tempo is not its own.
    useKeylock: true,
    // At most one brake in this many transitions
    brakeEvery: 8,
    // Brake: Mixxx's brake factor (larger: longer), the speed at which the
    // incoming track starts and the beats it takes to come up on its fader
    // Brake: the outgoing deck slows down (engine.brake; a smaller factor
    // stops later) while the incoming one comes up over brakeMs on the
    // crossfader, from the start of the brake (a transition on the clock,
    // [AutoDJ],next_transition_ms, Mixxx patch 0029)
    // Loop: the fade of the last loop, on the clock
    loopFadeBeats: 4,
    brakeFactor: 0.5,
    brakeMs: 3000,
    brakeBeats: 8,
    // Effect unit for echo and reverb (effect 1: Echo, effect 2: Reverb;
    // loaded by decksmithos-mixxx-autoconf). Unit 1 is the BEAT FX of the
    // skin and unit 2 that of 4-deck layouts.
    fxUnit: "[EffectRack1_EffectUnit4]",
    // Beats the outgoing fader takes to go down under echo/reverb (the
    // effect is fed that long; its tail goes on over the incoming track)
    fxFadeBeats: 4,
};

// beats: transition length (0: cut; beatsUnmatched: when the tempos are not
// matched); pre: beats before the transition start
// where its first part begins; match: needs matched tempos; keys: largest
// Camelot distance (undefined: any); weight: SMART weight when the tempos
// match / when they do not.
DecksmithAutoDJ.TRANSITIONS = {
    blend: {beats: 32, pre: 0, match: true, keys: 1, weight: [6, 0]},
    filter: {beats: 16, pre: 0, match: true, keys: 3, weight: [3, 0]},
    echo: {beats: 12, pre: 0, match: false, weight: [2, 4]},
    reverb: {beats: 12, pre: 0, match: false, weight: [1, 2]},
    fade: {beats: 16, beatsUnmatched: 8, pre: 0, match: false, weight: [3, 5]},
    loop: {beats: 8, pre: 8, match: true, weight: [2, 0]},
    riser: {beats: 8, pre: 16, match: true, weight: [2, 0]},
    brake: {beats: 0, pre: 4, match: false, weight: [0.5, 1]},
};

DecksmithAutoDJ.DECKS = ["[Channel1]", "[Channel2]"];
DecksmithAutoDJ.FADE_REQUEST_MS = 2000;
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
    // fade_now asked for (by this script or the FADE NOW button), in ms
    this.fadeRequestedAt = 0;
    this.connections.push(engine.makeConnection("[AutoDJ]", "fade_now", function(value) {
        if (value > 0) {
            DecksmithAutoDJ.fadeRequestedAt = Date.now();
        }
    }));
    this.connectNext();
    // A controller's crossfader moved to the waiting deck: Mixxx (patch 0021)
    // asks this script for the transition instead of fading at once
    var request = engine.makeConnection("[AutoDJ]", "fade_request", function() {
        if (engine.getValue("[AutoDJ]", "enabled")) {
            DecksmithAutoDJ.log("crossfader: fade now");
            DecksmithAutoDJ.requestTransition();
        }
    });
    if (request) {
        this.connections.push(request);
        engine.setValue("[AutoDJ]", "fade_by_script", 1);
    }
    this.log("ready");
    this.watchAudio();
    // Reloaded while Auto DJ runs (a controller plugged in sets up the
    // controllers again): plan the next transition again
    this.startTimer("resume", 1000, function() {
        DecksmithAutoDJ.connectNext();
        DecksmithAutoDJ.DECKS.forEach(function(group) {
            if (!DecksmithAutoDJ.plan && engine.getValue(group, "track_loaded") > 0 &&
                    !engine.getValue(group, "play")) {
                DecksmithAutoDJ.onTrackLoaded(group);
            }
        });
    }, true);
};

DecksmithAutoDJ.shutdown = function() {
    engine.setValue("[AutoDJ]", "fade_by_script", 0);
    this.reset();
    this.connections.forEach(function(c) {
        c.disconnect();
    });
};

// Audio dropouts (xruns): Mixxx counts the audio callbacks that came too
// late ([App],audio_latency_overload_count) but does not log them. Logged
// when the count grows (checked every minute), and every 15 minutes anyway.
DecksmithAutoDJ.AUDIO_CHECK_MS = 60000;
DecksmithAutoDJ.AUDIO_REPORT_EVERY = 15;
DecksmithAutoDJ.watchAudio = function() {
    var last = engine.getValue("[App]", "audio_latency_overload_count");
    var minutes = 0;
    this.log("audio overloads: " + last);
    engine.beginTimer(this.AUDIO_CHECK_MS, function() {
        var count = engine.getValue("[App]", "audio_latency_overload_count");
        minutes++;
        if (count !== last || minutes % DecksmithAutoDJ.AUDIO_REPORT_EVERY === 0) {
            DecksmithAutoDJ.log("audio overloads: " + count + " (+" + (count - last) +
                ", " + minutes + " min), latency usage " +
                Math.round(engine.getValue("[App]", "audio_latency_usage") * 100) + " %");
            last = count;
        }
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

DecksmithAutoDJ.beatsFor = function(name, matched) {
    var t = this.TRANSITIONS[name];
    return !matched && t.beatsUnmatched !== undefined ? t.beatsUnmatched : t.beats;
};

DecksmithAutoDJ.allowed = function(name) {
    // switched on unless the skin says otherwise (no skin: all on)
    return engine.getValue("[Skin]", "dsm_adj_use_" + name) !== 0;
};

DecksmithAutoDJ.choose = function(from, to) {
    var change = this.tempoChangePercent(
        engine.getValue(from, "bpm"), engine.getValue(to, "file_bpm"));
    var max = this.CONFIG.maxTempoChangePercent;
    var free = !this.synced(from) && !this.synced(to);
    // Over the limit but within reach: the playing track goes part of the
    // way first (lead, percent of its tempo, with a little margin)
    var lead = 0;
    if (change !== null && free && Math.abs(change) > max &&
            Math.abs(change) <= max + this.CONFIG.maxOutgoingTempoPercent) {
        lead = (change > 0 ? 1 : -1) *
            Math.min(this.CONFIG.maxOutgoingTempoPercent, Math.abs(change) - max + 0.5);
    }
    var matched = change !== null && free && (Math.abs(change) <= max || lead !== 0);
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
    return {name: name, matched: matched, change: change, keys: keys, lead: lead};
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
    this.stopTimer("lead");
    this.plan = {from: from, to: group, name: c.name, matched: c.matched, pre: false,
        chosen: false, change: c.change, keys: c.keys, lead: c.lead, leadStarted: false};
    engine.setValue("[AutoDJ]", "next_transition_beats",
        c.name ? this.beatsFor(c.name, c.matched) : -1);
    this.showNext();
    this.log("next: " + (c.name || "Mixxx crossfade (no transition allowed)") +
             " (tempo " + (c.change === null ? "?" : c.change.toFixed(1) + " %") +
             ", key steps " + (c.keys === null ? "?" : c.keys) + ")" +
             (c.lead ? "; the playing track first moves " + c.lead.toFixed(1) + " %" : ""));
};

// --- The planned transition on the skin ----------------------------------------

// [Skin],dsm_adj_next and dsm_adj_fade_now come from the skin, which may
// load after this script
DecksmithAutoDJ.connectNext = function() {
    if (this.nextConnection) {
        return;
    }
    this.nextConnection = engine.makeConnection("[Skin]", "dsm_adj_next", function(value) {
        DecksmithAutoDJ.onNextTapped(value);
    });
    if (this.nextConnection) {
        this.connections.push(this.nextConnection);
        this.showNext();
        // the skin's FADE NOW
        var fade = engine.makeConnection("[Skin]", "dsm_adj_fade_now", function(value) {
            if (value > 0 && engine.getValue("[AutoDJ]", "enabled")) {
                DecksmithAutoDJ.requestTransition();
            }
        });
        if (fade) {
            this.connections.push(fade);
        }
    }
};

DecksmithAutoDJ.showNext = function() {
    if (!this.nextConnection) {
        this.connectNext();
        return;
    }
    var names = Object.keys(this.TRANSITIONS);
    var shown = this.plan && this.plan.name ? names.indexOf(this.plan.name) + 1 : 0;
    if (engine.getValue("[Skin]", "dsm_adj_next") !== shown) {
        this.showingNext = true;
        engine.setValue("[Skin]", "dsm_adj_next", shown);
        this.showingNext = false;
    }
};

// A tap on the planned transition (the skin button went one state further):
// the next allowed transition from there that suits the tempos
DecksmithAutoDJ.onNextTapped = function(value) {
    var p = this.plan;
    if (this.showingNext) {
        return;
    }
    if (!p || p.pre || this.transition) {
        this.showNext();
        return;
    }
    var names = Object.keys(this.TRANSITIONS);
    if (p.name && value === names.indexOf(p.name) + 1) {
        return; // the script's own update arriving late: not a tap
    }
    var start = value > 0 ? value - 1 : 0;
    for (var i = 0; i < names.length; i++) {
        var name = names[(start + i) % names.length];
        if (this.allowed(name) && (p.matched || !this.TRANSITIONS[name].match)) {
            p.name = name;
            p.chosen = true; // the DJ's choice: not chosen again
            engine.setValue("[AutoDJ]", "next_transition_beats",
                this.beatsFor(name, p.matched));
            this.log("next (chosen): " + name);
            break;
        }
    }
    this.showNext();
};

// The tempo or key of a deck changed (its analysis finished, or it replaced
// a tempo from the file's tags): choose again with what is known now, unless
// the DJ chose the transition or it has begun
DecksmithAutoDJ.onAnalysis = function(group) {
    var p = this.plan;
    if (!p || p.chosen || p.pre || this.transition ||
            (group !== p.from && group !== p.to)) {
        return;
    }
    // tempo and key arrive one after the other
    this.startTimer("replan", 500, function() {
        var q = DecksmithAutoDJ.plan;
        if (!q || q.chosen || q.pre || DecksmithAutoDJ.transition) {
            return;
        }
        var change = DecksmithAutoDJ.tempoChangePercent(
            engine.getValue(q.from, "bpm"), engine.getValue(q.to, "file_bpm"));
        var keys = DecksmithAutoDJ.keyDistance(
            engine.getValue(q.from, "key"), engine.getValue(q.to, "key"));
        var same = change !== null && q.change !== null &&
            Math.abs(change - q.change) < 0.5 && keys === q.keys;
        if (!same) {
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
    if (p.lead && !p.leadStarted && seconds <= this.CONFIG.tempoLeadSeconds) {
        // done well before the transition (and what comes before it)
        this.startLead(p, Math.max(3, seconds - 20) * 1000);
    }
    var pre = this.TRANSITIONS[p.name].pre;
    if (pre <= 0 || seconds * 1000 > pre * this.beatMs(p.from)) {
        return;
    }
    this.startPre(p, seconds * 1000);
};

// The playing track moves towards the next one's tempo over "ms"
DecksmithAutoDJ.startLead = function(p, ms) {
    p.leadStarted = true;
    var group = p.from;
    var start = engine.getValue(group, "bpm");
    if (!(start > 0)) {
        return;
    }
    var target = start * (1 + p.lead / 100);
    this.stopRateTimer(group);
    if (this.CONFIG.useKeylock && !engine.getValue(group, "keylock")) {
        engine.setValue(group, "keylock", 1);
        this.state[group].keylockSet = true;
    }
    this.log("tempo: " + group + " " + start.toFixed(1) + " -> " + target.toFixed(1) +
             " bpm over " + Math.round(ms / 1000) + " s");
    var steps = Math.max(1, Math.round(ms / 250));
    var step = 0;
    this.startTimer("lead", 250, function() {
        step++;
        engine.setValue(group, "bpm", start + (target - start) * step / steps);
        if (step >= steps) {
            DecksmithAutoDJ.stopTimer("lead");
        }
    }, false);
};

// What comes before the transition, "ms" before it starts
DecksmithAutoDJ.startPre = function(p, ms) {
    // The tempo of a track can change after it was planned (analysed when
    // it was loaded): a transition that needs matched tempos becomes a fade
    if (this.TRANSITIONS[p.name].match && !this.synced(p.from) && !this.synced(p.to)) {
        var change = this.tempoChangePercent(
            engine.getValue(p.from, "bpm"), engine.getValue(p.to, "file_bpm"));
        if (change === null || Math.abs(change) > this.CONFIG.maxTempoChangePercent) {
            this.log(p.name + " needs matching tempos (" +
                     (change === null ? "unknown" : change.toFixed(1) + " %") + "): fade instead");
            p.name = "fade";
            engine.setValue("[AutoDJ]", "next_transition_beats", this.beatsFor("fade", false));
            this.showNext();
        }
    }
    p.pre = true;
    var beatMs = this.beatMs(p.from);
    switch (p.name) {
    case "echo":
    case "reverb":
        this.fxOn(p.from, p.name === "echo" ? 1 : 2);
        break;
    case "riser":
        this.rampFilter(p.from, 0.9, ms);
        break;
    case "loop":
        this.loopRoll(p.from, beatMs);
        break;
    case "brake":
        this.brake(p.from);
        break;
    }
};

// FADE NOW asked for by the DJ (the skin's FADE NOW, PLAY on the waiting
// deck): the planned transition as it would come by itself, on the next
// beat: what comes before it (riser 16 beats; the loop roll and the brake
// start the transition themselves), then the transition. Asked again meanwhile, or nothing
// planned: Mixxx's fade_now at once.
DecksmithAutoDJ.requestTransition = function() {
    var p = this.plan;
    if (this.transition) {
        return;
    }
    if (!p || !p.name || p.pre || this.timers.manual || !engine.getValue(p.from, "play")) {
        this.stopTimer("manual");
        this.fadeNow();
        return;
    }
    if (p.lead && !p.leadStarted && !p.chosen) {
        // No time to bring the tempos together first: a transition that
        // does not need them matched
        this.log("fade now before the tempos were brought together: fade");
        p.lead = 0;
        p.matched = false;
        p.name = "fade";
        engine.setValue("[AutoDJ]", "next_transition_beats", this.beatsFor("fade", false));
        this.showNext();
    }
    var beatMs = this.beatMs(p.from);
    // From the next bar of the playing track (Mixxx patch 0031,
    // [ChannelN],beats_to_bar), so that the bars of both tracks line up;
    // from the next beat without it
    var toBar = engine.getValue(p.from, "beats_to_bar");
    var toBeat;
    if (toBar > 0.05) {
        toBeat = toBar * beatMs;
        this.log("fade now: " + p.name + " from the next bar (" + toBar.toFixed(1) + " beats)");
    } else {
        var distance = engine.getValue(p.from, "beat_distance");
        toBeat = distance > 0 && distance < 1 ? (1 - distance) * beatMs : 0;
        this.log("fade now: " + p.name + " from the next beat");
    }
    this.startTimer("manual", toBeat, function() {
        if (DecksmithAutoDJ.plan !== p || p.pre || DecksmithAutoDJ.transition) {
            return;
        }
        var ms = DecksmithAutoDJ.TRANSITIONS[p.name].pre * beatMs;
        if (ms <= 0) {
            DecksmithAutoDJ.fadeNow();
            return;
        }
        DecksmithAutoDJ.startPre(p, ms);
        if (p.name === "loop" || p.name === "brake") {
            return; // they start the transition themselves
        }
        DecksmithAutoDJ.startTimer("manual", ms, function() {
            if (DecksmithAutoDJ.plan === p && !DecksmithAutoDJ.transition) {
                DecksmithAutoDJ.fadeNow();
            }
        }, true);
    }, true);
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
    // The transition starts with the roll and runs on the clock over the
    // roll and the fade of its last loop (Mixxx patch 0029: the looping
    // deck's position does not advance): the incoming track comes up while
    // the loops get shorter; the old track is not heard again
    var rollBeats = 0;
    this.LOOP_STEPS.forEach(function(s) {
        rollBeats += s[0] * s[1];
    });
    var beats = rollBeats + this.CONFIG.loopFadeBeats;
    engine.setValue("[AutoDJ]", "next_transition_beats", beats);
    engine.setValue("[AutoDJ]", "next_transition_ms", beats * beatMs);
    this.loopHeld = group;
    var step = 0;
    var next = function() {
        if (step >= DecksmithAutoDJ.LOOP_STEPS.length) {
            return; // the last loop rolls on until the transition ends
        }
        var s = DecksmithAutoDJ.LOOP_STEPS[step++];
        engine.setValue(group, "beatloop_size", s[0]);
        if (!engine.getValue(group, "loop_enabled")) {
            engine.setValue(group, "beatloop_activate", 1);
        }
        DecksmithAutoDJ.startTimer("loop", s[0] * s[1] * beatMs, next, true);
    };
    next();
    this.fadeNow();
};

// Vinyl brake of the outgoing deck; the transition starts with it and runs
// on the clock (Mixxx patch 0029: the braked deck's position barely moves),
// so the incoming track comes up while the outgoing one slows down. If the
// deck stops before Auto DJ started the transition (an older Mixxx), the
// incoming deck is started here.
// (Mixxx's spinback is not used: started on a playing deck it ends at once.)
DecksmithAutoDJ.brake = function(group) {
    var to = this.other(group);
    var started = Date.now();
    engine.brake(this.deckNumber(group), true, this.CONFIG.brakeFactor);
    this.log("brake");
    // The transition starts with the brake and follows the clock: the
    // incoming track comes up while the outgoing one slows down
    engine.setValue("[AutoDJ]", "next_transition_beats", this.CONFIG.brakeBeats);
    engine.setValue("[AutoDJ]", "next_transition_ms", this.CONFIG.brakeMs);
    this.fadeNow();
    this.startTimer("brake", 20, function() {
        if (!engine.getValue(group, "play")) {
            DecksmithAutoDJ.stopTimer("brake");
            DecksmithAutoDJ.log("brake: stopped after " + (Date.now() - started) + " ms");
            if (!DecksmithAutoDJ.transition) {
                // Auto DJ did not start the transition (an older Mixxx)
                DecksmithAutoDJ.startAfterStop(group, to);
            }
        } else if (Date.now() - started > 4 * DecksmithAutoDJ.CONFIG.brakeMs) {
            DecksmithAutoDJ.stopTimer("brake");
        }
    }, false);
};

// The outgoing deck stopped before the transition (end of a brake): Auto DJ
// does not go on by itself, so start the incoming deck and move the
// crossfader to it
DecksmithAutoDJ.startAfterStop = function(from, to) {
    this.log("brake: " + from + " stopped first, starting " + to);
    this.rampVolume(to, 0, 0);
    this.startTransition(from, to);
    engine.setValue(to, "play", 1);
    var side = engine.getValue(to, "orientation") === 0 ? -1 : 1;
    if (engine.getValue("[Mixer Profile]", "xFaderReverse") > 0) {
        side = -side;
    }
    engine.setValue("[Master]", "crossfader", side);
    this.endTransition();
};

DecksmithAutoDJ.releaseLoop = function(group) {
    if (engine.getValue(group, "loop_enabled")) {
        engine.setValue(group, "reloop_toggle", 1);
    }
};

// --- The transition -----------------------------------------------------------

// PLAY pressed (on any controller, or the keyboard) on the waiting deck while
// Auto DJ runs: start the transition now (FADE NOW) instead of playing the
// track under the one on air (not tied to the headphone cue: the waiting
// deck has it on while Auto DJ runs).
// Auto DJ itself sets next_transition_beats back to -1 just before it
// starts the waiting deck; a transition still a while away (and no fade_now
// just asked for) means the press came from a DJ.
DecksmithAutoDJ.manualStart = function(group) {
    if (Date.now() - this.fadeRequestedAt < this.FADE_REQUEST_MS) {
        return false;
    }
    return engine.getValue("[AutoDJ]", "next_transition_beats") >= 0 ||
        engine.getValue("[AutoDJ]", "seconds_to_transition") > 0.5;
};

DecksmithAutoDJ.fadeNow = function() {
    this.fadeRequestedAt = Date.now();
    engine.setValue("[AutoDJ]", "fade_now", 1);
    engine.setValue("[AutoDJ]", "fade_now", 0);
};

DecksmithAutoDJ.onPlay = function(group, value) {
    if (!engine.getValue("[AutoDJ]", "enabled")) {
        return;
    }
    var other = this.other(group);
    if (value > 0 && !engine.getValue(other, "play") && !this.plan && !this.transition &&
            engine.getValue(other, "track_loaded") > 0) {
        // Auto DJ started: the next track was loaded before this one played
        this.onTrackLoaded(other);
        return;
    }
    if (value > 0 && engine.getValue(other, "play") > 0 && !this.transition &&
            this.manualStart(group)) {
        this.log("PLAY on " + group + ": fade now");
        engine.setValue(group, "play", 0);
        this.requestTransition();
    } else if (value > 0 && engine.getValue(other, "play") > 0 && !this.transition) {
        this.startTransition(other, group);
    } else if (value === 0 && this.transition && this.transition.from === group) {
        this.endTransition();
    }
};

DecksmithAutoDJ.startTransition = function(from, to) {
    var p = this.plan && this.plan.from === from && this.plan.to === to ? this.plan : null;
    var name = p ? p.name : null;
    this.plan = null;
    this.stopTimer("manual");
    this.stopTimer("lead");
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
    case "loop":
        if (this.loopHeld !== from) {
            // not started by the roll (an older Mixxx): out of the loop now,
            // the fade follows the deck's position
            this.stopTimer("loop");
            this.releaseLoop(from);
        }
        this.loopHeld = null;
        // falls through: the fade of a blend
    case null:
    case "blend":
    case "fade":
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
    case "riser":
        // the outgoing track has no bass left: nothing to swap
        this.transition.swapped = true;
        if (!this.state[from].filterTimer &&
                engine.getParameter(this.filterGroup(from), "super1") < 0.85) {
            // FADE NOW before the sweep: a quick one
            this.rampFilter(from, 0.9, 2 * beatMs);
        }
        break;
    case "echo":
    case "reverb":
        // The effect and the incoming track start together; the effect is
        // fed for a few beats, its tail plays over the incoming track
        this.transition.swapped = true;
        if (!this.fx) {
            this.fxOn(from, name === "echo" ? 1 : 2);
        }
        this.rampVolume(from, 0, this.CONFIG.fxFadeBeats * beatMs);
        break;
    case "brake":
        // started with the brake: the crossfader brings the incoming deck
        // up (on the clock) while the outgoing one slows down; the brake
        // timer stays on to log when the deck stopped
        this.transition.swapped = true;
        if (this.state[to].savedVolume !== undefined) {
            this.rampVolume(to, null, 0);
        }
        break;
    default:
        this.transition.swapped = true;
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
    this.fxOff();
    if (t.name === "loop") {
        this.stopTimer("loop");
        this.releaseLoop(t.from);
    }
    if (t.name === "brake") {
        // Auto DJ stopped the deck; the brake must not go on into the next
        // track loaded there
        engine.brake(this.deckNumber(t.from), false);
    }
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
    this.showNext();
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
