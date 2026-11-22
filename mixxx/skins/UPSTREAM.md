# Third-party Mixxx skins

DecksmithOS ships adapted versions of two GPL-3.0 skins. The authors are
credited in each `skin.xml` (`<author>`, `<description>`) and each `LICENSE`
file is kept. These skins are licensed under GPL-3.0, independently of the
DecksmithOS project license.

| Directory | Based on | Upstream | Revision | Author | License |
|---|---|---|---|---|---|
| `DecksmithOS Standalone/` | XDJ OPEN SOURCE | https://github.com/marcmonka/xdj-open-source-skin-mixxx | `9139ff1` (2026-06-30) | Marc Monka | GPL-3.0 |
| `DecksmithOS Compact/` | Pioneered | https://github.com/timewasternl/Pioneered | `b1b6186` (2024-11-21) | Sven Boekelder | GPL-3.0 |

LateNight ships with Mixxx, is not copied here and is not renamed.

To see the DecksmithOS changes, diff a directory against the upstream revision above.

## DecksmithOS changes (both skins)

- Renamed. Third-party product names and logos removed from what the user
  sees (title, description, loading-screen logo, preview image). The loading
  screen shows the DecksmithOS logo, cut from the Plymouth splash
  (`build/stage-decksmithos/01-configure-base-runtime/files/splash.png`).
- The library page is bound to the standard `[Skin],show_maximized_library`
  control instead of the skin-private `[Tab],library`. The on-screen BROWSE
  button and the library button of any controller mapping that uses the
  standard control switch the same page. 11 bundled Mixxx 2.5.6 mappings use
  this control; none use `[Tab]`.
- Deprecated control keys replaced: `[Master],maximize_library`,
  `[Microphone],show_microphone`, `[PreviewDeck],show_previewdeck` and
  `[Library],show_coverart` become their `[Skin],...` equivalents.
- Invalid `<TooltipId>` entries removed, so both skins load without skin
  parser warnings in Mixxx 2.5.6.

## DecksmithOS Standalone only

Reworked in 2026-11 after the standalone-player layout the user chose as the
reference (layout and features only; no third-party names, logos or artwork).
Text is sized at about 85 % of the reference's physical size on the 7-inch
panel (reference pixel sizes x 1.19), touch targets are 30-44 px tall.

- Top bar (48 px): touch navigation SOURCE, BROWSE/BACK, TAG LIST, PLAYLIST,
  SEARCH, MENU; master level, recording, clock. SOURCE / TAG LIST / PLAYLIST /
  SEARCH go through the skin bridge (`mixxx/controllers/DecksmithOS-SkinBridge.js`,
  loaded with the Auto DJ script on the virtual MIDI device): library page with
  the sidebar on Computer / Auto DJ / Playlists, or the search box focused.
- Main page: deck info sidebar (key, loop), waveforms in three-band colours
  (blue low, orange mid, cream high; also used by the RGB and Stacked types),
  BEAT FX panel (effect, CH SELECT 1/2/MASTER, tempo, beat length, on/off,
  pad page buttons, zoom), pad row, and per-deck panels (title, QUANTIZE, MT,
  SYNC, remaining/elapsed time, tempo and range, BPM with MASTER on the sync
  leader, overview with hot cues, loops, intro/outro and the rekordbox phrase
  band of Mixxx patch 0007).
- Pad row pages: HOT CUE (A-H per deck, cue colours), BEAT FX (the three
  effects of unit 1, X-PAD 1/32-2 beats while held), RELEASE FX per deck
  (brake and backspin short/long, BUILD UP, MUTE, DUCKING while held). X-PAD
  and RELEASE FX go through the skin bridge.
- Library page: 26 px text in ~50 px rows (10 rows), LOAD 1 / LOAD 2 and
  REQUEST (Auto DJ request, Mixxx patch 0010) next to the search box, 44 px
  sidebar rows, compact deck strip at the bottom; 12 px scroll bars (the
  lists scroll by dragging with Mixxx patch 0012).
- MENU page: AUTO DJ REQUEST BUTTON, LEARN / SET / CLEAR, binds one console
  button to REQUEST (Mixxx patch 0011).
- Scrolling waveforms: red downbeats and a bar.beat counter (Mixxx patch 0007).
- Fonts: `Liberation Sans Narrow` (condensed, like the reference), falling
  back to `Open Sans Condensed` and `Liberation Sans`.

## Verification

Both skins were checked with Mixxx 2.5.6 (DecksmithOS build) at 1280×720
under Xvfb, with two tracks loaded. Checked: two waveforms, beatgrid,
playhead, BPM/key, and BROWSE/BACK/settings switched by simulated touches.
Not yet verified: real hardware (CM5 rendering performance, Touch Display 2
touch coordinates), and controller-driven page switching.

The 2026-11 rework was checked on the CM5 with the Touch Display 2 by
screenshots (two tracks loaded, every page and pad page, the navigation
buttons by simulated taps). Not yet verified: touch on the panel, X-PAD and
RELEASE FX by ear, the phrase band with a rekordbox USB, and the GPU cost of
the Stacked waveform type.
