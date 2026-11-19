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

- Top bar is 44 px instead of 28 px, for touch. BROWSE/BACK is 110×44 and the
  settings button is 56×44; BROWSE/BACK text is 13 px instead of 8 px.
- Font: `Helvetica Neue` (not available) replaced by `Liberation Sans`
  (Helvetica metrics) with `Open Sans` as fallback. Both are installed in the image.

## Verification

Both skins were checked with Mixxx 2.5.6 (DecksmithOS build) at 1280×720
under Xvfb, with two tracks loaded. Checked: two waveforms, beatgrid,
playhead, BPM/key, and BROWSE/BACK/settings switched by simulated touches.
Not yet verified: real hardware (CM5 rendering performance, Touch Display 2
touch coordinates), and controller-driven page switching.
