# Flac

A macOS app for playing FLAC and other hi-res audio, built with SwiftUI. The
whole point is bit-perfect playback — audio goes straight from the decoder
to the output device with no resampling, no mixer graph, and nothing
touching the signal unless you turn it on yourself.

<img width="1271" height="791" alt="CleanShot 2026-07-28 at 17 07 34" src="https://github.com/user-attachments/assets/5467a9be-d3bd-4cce-9b22-b93a4cd9273a" />

## What it does

Plays FLAC, ALAC (`.m4a`), PCM (`.wav`/`.aiff`), and DSD (`.dsf`, over DoP).
Gapless between tracks that share the same sample rate, bit depth, and
channel count.

For managing music there's folder scanning with live watched folders
(FSEvents), M3U import/export, and an album view — a cover grid plus an
Apple Music–style detail page with search.

The equalizer is a 6-band graphic EQ with 15 presets, and it's fully
bypassable so it never gets in the way of bit-perfect output when you don't
want it.

Two screens exist specifically for people who care whether their "hi-res"
files are actually hi-res: Signal Path shows the real output format,
bit-perfect status, and a live waveform pulled straight from the render
callback, and Spectrogram runs a full-file FFT to flag files that were
upsampled from something lossy. There's also on-demand FLAC integrity
verification, checking a file's audio against the MD5 it has embedded in
its own STREAMINFO block.

The now-playing bar has shuffle, repeat, its own independent digital
volume, and output device switching, with Liquid Glass styling on macOS 26+.

## Requirements

- macOS 14+
- Xcode / Swift 6
- `flac` from Homebrew (`brew install flac`) — needed for libFLAC via pkg-config

## Building

```sh
swift build
```

`swift build` alone links against your Homebrew prefix's absolute paths, so
it won't run as a standalone app. To get an actual `.app` bundle (bundles
libFLAC/libogg and re-signs everything):

```sh
./Scripts/build-app.sh debug   # or: release
open .build/debug/FlacPlayer.app
```

## Testing

```sh
swift test
```

## Distribution

`Scripts/notarize.sh` does a release build, re-signs it with a Developer ID
identity and hardened runtime, and submits it for notarization. Check the
script's header for the one-time setup — you'll need a Developer ID
certificate and stored `notarytool` credentials.

## Project layout

- `Sources/FlacPlayerCore` — decoding, the bit-perfect output engine, the
  SwiftData library/playlist models, the EQ's DSP, and frequency analysis.
- `Sources/FlacPlayer` — the actual SwiftUI app: sidebar, the library/album/
  playlist views, the now-playing bar, equalizer UI, and the player/inspector
  models.
- `Sources/CFLAC` — shim for the libFLAC system library.
- `Tests/FlacPlayerCoreTests` — unit tests, plus the audio fixtures they run
  against.
