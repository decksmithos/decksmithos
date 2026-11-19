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
