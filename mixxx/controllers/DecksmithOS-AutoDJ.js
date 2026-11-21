// DecksmithOS Auto DJ transitions (AGENTS.md #31, stage 3).
//
// A controller script without controls: Mixxx runs it for a virtual MIDI
// device (ALSA snd-virmidi), so it needs no Mixxx patch. Mixxx's own Auto DJ
// keeps doing the queue, the track loading and the crossfader; this script
// only acts around each Auto DJ transition between decks 1 and 2:
//
//   transition start (Auto DJ starts the next track while the other plays)
//     - if the tempos are close enough (half/double tempo counts as the
//       same), the incoming track takes the playing track's tempo
//       (beatsync_tempo) and phase (beatsync_phase), with keylock on so that
//       its key does not move;
//     - the incoming track's bass is taken out (low EQ);
//   crossfader past the middle
//     - bass swap: the outgoing bass out, the incoming bass back in, over
//       a short ramp;
//   transition end (the outgoing deck stops)
//     - the outgoing deck gets its EQ, tempo and keylock back for its next
//       track;
//     - the incoming deck slowly returns to its own tempo (rate 0), so that a
//       whole set does not drift to the first track's tempo; keylock goes
//       off once it is there.
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
};

DecksmithAutoDJ.DECKS = ["[Channel1]", "[Channel2]"];
DecksmithAutoDJ.STEP_MS = 50;

DecksmithAutoDJ.init = function(id, debugging) {
    this.debugging = debugging;
    this.connections = [];
    // per deck: saved low EQ value (or undefined), timers
    this.state = {};
    this.DECKS.forEach(function(group) {
        DecksmithAutoDJ.state[group] = {
            savedLow: undefined,
            lowTimer: 0,
            rateTimer: 0,
            keylockSet: false,
        };
        DecksmithAutoDJ.connections.push(
            engine.makeConnection(group, "play", function(value) {
                DecksmithAutoDJ.onPlay(group, value);
            }));
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
    // {from, to, swapped} while a transition runs
    this.transition = null;
    this.log("ready");
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

DecksmithAutoDJ.eqGroup = function(group) {
    return "[EqualizerRack1_" + group + "_Effect1]";
};

DecksmithAutoDJ.synced = function(group) {
    return engine.getValue(group, "sync_enabled") > 0;
};

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
    this.transition = {from: from, to: to, swapped: false};
    // The outgoing deck stops returning to its own tempo: its tempo is the
    // one the incoming track follows now.
    this.stopRateTimer(from);

    var change = this.tempoChangePercent(
        engine.getValue(from, "bpm"), engine.getValue(to, "file_bpm"));
    if (this.synced(from) || this.synced(to)) {
        this.log("sync lock is on: tempo left to it");
    } else if (change === null) {
        this.log("tempo unknown: plain crossfade");
    } else if (Math.abs(change) > this.CONFIG.maxTempoChangePercent) {
        this.log("tempo change " + change.toFixed(1) + " % too large: plain crossfade");
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

    // Incoming bass out until the swap.
    this.rampLow(to, 0);
    // A transition of zero length: swap now.
    this.onCrossfader(engine.getValue("[Master]", "crossfader"));
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
    if (!t.swapped) {
        this.rampLow(t.to, null);
    }
    // The outgoing deck is stopped: give it back its EQ, tempo and keylock
    // for the next track Auto DJ loads into it.
    this.restoreDeck(t.from);
    this.returnToOwnTempo(t.to);
};

// Ramp the low EQ of a deck to "target" (normalized 0..1), or back to the
// value it had before the script changed it (target null).
DecksmithAutoDJ.rampLow = function(group, target) {
    var st = this.state[group];
    var eq = this.eqGroup(group);
    if (st.lowTimer) {
        engine.stopTimer(st.lowTimer);
        st.lowTimer = 0;
    }
    if (target === null) {
        if (st.savedLow === undefined) {
            return;
        }
        target = st.savedLow;
        st.savedLow = undefined;
    } else if (st.savedLow === undefined) {
        st.savedLow = engine.getParameter(eq, "parameter1");
    }
    var start = engine.getParameter(eq, "parameter1");
    var steps = Math.max(1, Math.round(this.CONFIG.bassSwapMs / this.STEP_MS));
    var step = 0;
    st.lowTimer = engine.beginTimer(this.STEP_MS, function() {
        step++;
        engine.setParameter(eq, "parameter1", start + (target - start) * step / steps);
        if (step >= steps) {
            engine.stopTimer(st.lowTimer);
            st.lowTimer = 0;
        }
    });
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

DecksmithAutoDJ.restoreDeck = function(group) {
    this.stopRateTimer(group);
    var st = this.state[group];
    if (st.lowTimer) {
        engine.stopTimer(st.lowTimer);
        st.lowTimer = 0;
    }
    if (st.savedLow !== undefined) {
        engine.setParameter(this.eqGroup(group), "parameter1", st.savedLow);
        st.savedLow = undefined;
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
    this.DECKS.forEach(function(group) {
        var st = DecksmithAutoDJ.state[group];
        DecksmithAutoDJ.stopRateTimer(group);
        if (st.lowTimer) {
            engine.stopTimer(st.lowTimer);
            st.lowTimer = 0;
        }
        if (st.savedLow !== undefined) {
            engine.setParameter(DecksmithAutoDJ.eqGroup(group), "parameter1", st.savedLow);
            st.savedLow = undefined;
        }
        if (!engine.getValue(group, "play")) {
            DecksmithAutoDJ.restoreDeck(group);
        }
    });
};
