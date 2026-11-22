# Mixxx package

DecksmithOS pins its Mixxx version here instead of using whatever the base
release ships (Debian trixie has 2.5.0).

The Debian source package named in `mixxx.conf` (currently `2.5.6+dfsg-3`
from sid) is rebuilt **unchanged** against Debian trixie arm64. The result
links against trixie's Qt and FFmpeg. Installing the sid binary directly
would pull glibc, Qt and FFmpeg from sid into the image, so it is not used.

## Files

| File | Purpose |
|---|---|
| `mixxx.conf` | Pinned source version, snapshot fallback, local version suffix |
| `build-mixxx-deb.sh` | Fetch and verify the source, bump the version, install build deps, build |
| `make-stable-patch.sh` | Make `patches/0000-*`: upstream stable-branch fixes since the release; checks our patches on top |
| `pin-release.sh` | Pin a published release's `.deb`s by SHA256 into `release.sha256` |
| `release.sha256` | Pinned release assets used by the image build (created by `pin-release.sh`) |
| `../../.github/workflows/mixxx-deb.yml` | CI build on a native `ubuntu-24.04-arm` runner |

`dget` checks the `.dsc` signature against `debian-keyring` and the checksums
of every source file. If the version has left the Debian pool, the script
falls back to snapshot.debian.org at `MIXXX_SNAPSHOT_TIMESTAMP`.

Version scheme: `<debian version>~deb13decksmithosN`. It sorts above
trixie's own Mixxx and below the Debian version it was taken from.

## Building

**CI (normal path).** Run the *Mixxx package* workflow from the Actions tab.
Leave *publish* off to only build. Turn it on to also create a release tagged
`mixxx/<version>`, with `~` replaced by `_`. Existing releases are never
overwritten; increase the `N` in `MIXXX_LOCAL_SUFFIX` to publish a new build.
Pushes and pull requests that touch `build/mixxx/` build without publishing.

**Locally on a trixie arm64 system (e.g. a CM5 dev image):**

```sh
sudo CCACHE_DIR=/var/cache/ccache build/mixxx/build-mixxx-deb.sh out/
```

**Quick self-test without compiling.** This runs in an emulated arm64
container on an x86 host:

```sh
sudo docker run --rm --platform linux/arm64 \
  -v "$PWD/build/mixxx:/src:ro" -v "$PWD/out:/out" debian:trixie \
  /src/build-mixxx-deb.sh --prepare-only /out
```

Set `MIXXX_NOCHECK=1` to skip the upstream test suite.

## Patches and their order

The build appends `patches/*.patch` (in name order) to Debian's quilt series,
so the source is patched in this order:

1. Debian's own patches (`debian/patches/series` of the source package).
2. `0000-mixxx-<branch>-branch-<sha>.patch`: the bug fixes on the upstream
   stable branch since the release Debian packages (for 2.5.6: branch `2.5`,
   the future 2.5.7). Code, skins, controller mappings and CMake only; no CI,
   packaging or translations; the version stays the release's.
3. `0001-*` and later, on top of the stable branch: changes taken from
   upstream developers that are not in a branch yet, then the DecksmithOS
   patches. One change per patch, so that each can be dropped when upstream
   has it, or sent upstream on its own:

| Patch | What | Upstream |
|---|---|---|
| `0001-ronso0-gui-show-preferences-control` | `[Controls],show_preferences` opens the preferences (skin settings button) | ronso0's commit, proposed on #13266 |
| `0002-decksmithos-auto-enable-controllers` | enable a never-configured controller when exactly one mapping matches | ours |
| `0003-decksmithos-no-output-warning-setting` | "do not show again" for the "No Output Devices" warning; keeps `soundconfig.xml` meanwhile | for #13252 |
| `0004-decksmithos-appliance-sound-dialogs` | `DECKSMITHOS_NO_SOUND_DIALOGS`: no busy/error sound dialogs at start | appliance only |
| `0005-decksmithos-sound-controller-hotplug` | `DECKSMITHOS_SOUND_HOTPLUG_HOOK`: sound and controller hotplug | appliance only (upstream waits for PipeWire/libremidi) |
| `0006-decksmithos-autodj-harmonic-order` | Auto DJ "Harmonic" ordering, `[AutoDJ],sort_harmonic` | ours |
| `0007-decksmithos-rekordbox-phrases` | rekordbox phrases (PSSI) as a band in the track overview; downbeats and a bar.beat counter in the allshader waveforms (skin options `PhraseBandHeight`, `DownbeatColor`, `ShowDownbeats`, `ShowBarCounter`, `DownbeatFromIntroStart`); stored as an extra analysis row, no schema change | ours (upstream PRs #16581/#16582 target main's new renderer and were not ported) |
| `0008-numark-mixtrack3-wheel-edge-loop-roll-beats-knob` | Mixtrack (Pro) 3 mapping: wheel edge seeks on a stopped deck and no pitch bend while scratching; options for SHIFT+Auto Loop rolls and a BEATS knob that halves/doubles the effect time; sampler gain fix | candidate for upstream (user submits) |
| `0009-quit-gracefully-on-sigterm` | SIGTERM quits like File > Exit (library, settings, effects.xml saved), second SIGTERM kills; Unix | candidate for upstream, #15767 (user submits) |
| `0010-decksmithos-autodj-requests` | Auto DJ requests, `[Library],AutoDjAddRequest`: the selected track goes where it fits best (key, tempo) among the next N queued tracks (Preferences > Auto DJ > Requests, default 5; optional request order), after the cued track; a queued track moves up instead; requests highlighted in the queue | ours |
| `0011-decksmithos-midi-request-button` | `[AutoDJ],request_learn` / `request_learn_clear` / `request_learned`: learn one MIDI controller button for requests from the skin, stored in `mixxx.cfg`, mapping untouched | appliance only |
| `0012-decksmithos-touch-scroll` | `DECKSMITHOS_TOUCH_SCROLL`: library sidebar and track tables scroll by dragging (kinetic); no dragging tracks out of them then | appliance only |
| `0013-decksmithos-browse-sources` | `DECKSMITHOS_BROWSE_SOURCES="LABEL=/path:..."`: "Computer" becomes "Sources" with only these folders, each shown while a drive is mounted there (checked every 2 s) | appliance only |
| `0014-decksmithos-touch-keyboard` | `DECKSMITHOS_TOUCH_KEYBOARD`: on-screen keyboard at the bottom of the window while the search box or any other text field has the focus | appliance only |
| `0015-decksmithos-library-sidebar` | sidebar order / hidden / labels (`[Library] SidebarOrder`, `SidebarHidden`, `SidebarLabels`, editor in Preferences > Library > Sidebar); `[Library],show_<key>` opens a section, `active_<key>`, `sidebar_up`, `sidebar_at_top` | ours |
| `0016-decksmithos-usb-library-import` | `DECKSMITHOS_USB_IMPORT`: a rekordbox/Serato drive's playlists and crates become locked playlists "USB ▸ ..." first in Playlists (gone when the drive is removed); the rekordbox analysis (grid, cues, loops, phrases, key, colour) is applied to its tracks, rekordbox wins; never writes to the drive. ANLZ/PDB and crate reading shared with the Rekordbox/Serato views | appliance only |
| `0017-decksmithos-removable-drives` | `DECKSMITHOS_DRIVES` / `DECKSMITHOS_EJECT_COMMAND`: `[Drives],mounted_<n>`, `eject_<n>`, `eject_error_<n>` for EJECT buttons | appliance only |
| `0018-decksmithos-thread-placement` | `DECKSMITHOS_AUDIO_CPUS`: the audio thread moves to its own CPU; `DECKSMITHOS_BACKGROUND_NICE`: analysis and library scan below the GUI | appliance only |
| `0019-decksmithos-no-scan-dialog` | `DECKSMITHOS_NO_SCAN_DIALOG`: no library scan window (scans started by a new drive run in the background) | appliance only |
| `0020-decksmithos-phrase-detection` | Phrases (and the first downbeat) detected from loudness and bass changes for tracks without rekordbox phrase data, snapped to an 8-bar grid, labelled like rekordbox ("High" mood); stored in the 0007 track structure with a source marker, never over rekordbox data, which always replaces it; `[Library],DetectPhrases` (default on); already analyzed tracks get it when loaded. Ideas from upstream PRs #16582 and #17404 | candidate for upstream discussion (user submits) |
| `0021-decksmithos-autodj-transitions` | Auto DJ: `[AutoDJ],next_transition_beats` (length of the next transition in beats, 0 = cut; also for `fade_now`), `seconds_to_transition` (read only), `phrase_align` (`[Auto DJ] PhraseAlign`, default on: transitions start on phrase starts, the incoming track is cued on one) | candidate for upstream discussion (user submits) |
| `0022-decksmithos-autodj-touch-controls` | `[Library],AutoDjAddAllBottom` (the whole list shown to the Auto DJ queue), `[Library],crate_selected` / `crate_autodj_source` (crate as Auto DJ source), `[AutoDJ],random_fill` (preference "Enable random track addition to queue"): for a touch screen without context menus | appliance; parts could go upstream |

Refresh 0000 with `build/mixxx/make-stable-patch.sh [branch [commit]]`
(default: head of `2.5`). It also tries each DecksmithOS patch on top and
reports, per patch:

| Result | Meaning |
|---|---|
| `ok` | applies |
| `ALREADY UPSTREAM` | applies reversed: the stable branch has this change; delete the patch |
| `PARTLY UPSTREAM` | some files already have the change; drop those hunks |
| `CONFLICT` | upstream changed the code around it; refresh its context |

When Debian packages the next release (e.g. 2.5.7), update `mixxx.conf`
(see below) and regenerate 0000; it then holds only what came after that
release, or delete it if there is nothing.

## Updating Mixxx

1. Set `MIXXX_SOURCE_VERSION` to the new Debian source version.
2. Set `MIXXX_SNAPSHOT_TIMESTAMP` from
   `https://snapshot.debian.org/mr/package/mixxx/<version>/srcfiles?fileinfo=1`.
3. Reset `MIXXX_LOCAL_SUFFIX` to `~deb13decksmithos1`.
4. Run the workflow, test the packages on the target hardware, then publish.

## Using the packages in the image

`build.sh` puts the packages into the pi-gen stage, and
`stage-decksmithos/00-install-packages/01-run.sh` installs them with
`apt-get` (dependencies from trixie) and `apt-mark hold`s them. Where
they come from is set by `DECKSMITHOS_MIXXX`:

| Value | Source |
|---|---|
| `release` (default) | GitHub release of `MIXXX_RELEASE_REPO`, files and hashes from `release.sha256` |
| `dir:/path` | local `.deb`s, e.g. a downloaded workflow artifact, checked against its `SHA256SUMS` |
| `debian` | trixie's own `mixxx` (2.5.0, no DecksmithOS patches); build tests only |

After publishing a release, pin it once and commit the result:

```sh
build/mixxx/pin-release.sh      # needs curl and jq; writes build/mixxx/release.sha256
```

`pin-release.sh` downloads the arm64 and `all` `.deb` assets, which
excludes `-dbgsym`. It checks them against the release's `SHA256SUMS`
and records their hashes. From then on the build downloads exactly these
files and stops if a hash differs.
