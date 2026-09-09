# HowFried

A small golden retriever with a very reasonable request: take a walk between prompts.

Local macOS 14+ prototype. SwiftUI + AppKit, built-in SQLite, no third-party packages,
accounts, servers, tracking SDKs, or generated art. One primary display and one dog.

## Build and launch

Requires Apple's Swift toolchain / Command Line Tools. From this directory:

```sh
swift test
bash scripts/build.sh
```

The build script creates a **new**, uniquely named `artifacts/<build>/HowFried.app` and
prints its absolute path. Open that bundle in Finder or with `open '/absolute/path/HowFried.app'`.
It does not install into Applications, change login items, or modify providers. Local
ad-hoc signing is for this Mac; this is not a notarized distribution release.

The app opens a compact dashboard and adds a paw to the menu bar. Closing the dashboard
leaves the menu bar app running. Use Quit HowFried to exit.

## What it does

- Counts actual local Claude Code/Codex submission-hook invocations across sessions.
- Choose a prompt limit (default 20), elapsed session timer (60 minutes), or optional
  Claude-only local token threshold (100,000 observed tokens).
- Paws pace beside the notch for 30 seconds, then a dog enters and a park scene asks you
  to take five minutes away. The timer starts after the entrance finishes.
- Snooze for ten minutes, skip, pause observation, or quit at any time.
- Default global skip shortcut: **Control–Option–Command–B**. Change its modifiers/key in
  the dashboard. A failed registration is shown. Escape works while the overlay has focus.
- Reduce Motion replaces the entrance with a static pet and brief fade. Without a notch,
  the warning sits around a small top-centre capsule. Other displays remain usable.

This is a break reminder, not a token-spending firewall. Agents can continue working
under the overlay. “Fried” is a joke, not a diagnosis. Session time includes gaps and
does not measure attention.

## Connect providers

See [the additive setup guide](docs/SETUP.md). Observation is off until enabled. Provider
hooks must be separately configured and trusted by the owner. No real provider settings
have been changed by this project. Synthetic testing and live testing are reported separately.

## Data and limits

The private store is `~/Library/Application Support/HowFried/activity.sqlite`. It keeps
hashed session/event identities, timestamps, source labels, token numbers, settings and
break outcomes. It does not save prompts, replies, tool arguments, credentials or project
paths. Hook stdin is parsed in memory and discarded. The opt-in Claude scanner reads usage
records in memory; only usage metadata and hashed checkpoints are retained.

SQLite's atomic insert and unique identity constraint protect concurrent writes and
replays. Seven-day retention removes old **rows inside the app-owned database**, without
deleting files. No unrelated files or user configurations are cleaned up. Hook observation
fails open on errors and never waits for the dog or an approval. Very busy/unavailable
storage or invalid/oversized payloads may drop observations; this is not billing-grade data.

For isolated manual tests, launch the bundle's executable with `HOWFRIED_DATA_DIR` set to
an absolute empty project directory. `HOWFRIED_QA=1` marks the dashboard Demo Lab, uses
only synthetic Claude logs inside that directory, and speeds preview time by 6×. Real
prompt/time rules are never accelerated. Preview actions do not change daily totals.

## Project map

- `Sources/HowFriedCore`: provider parsing, private store, incremental usage scanner,
  deterministic break state machine.
- `Sources/HowFriedHook`: quiet, bounded native stdin observer; no approval responses.
- `Sources/HowFried`: menu bar/dashboard, global shortcut, warning panel, original vector
  pet and park overlay.
- `Tests/HowFriedCoreTests`: synthetic data only; retained under `.qa/tests` without cleanup.

New integrations should emit normalized `ActivityEvent` records with source/session/event
identity. Keep their parsers separate from the engine and views. Declare unsupported
signals unavailable. Editor-process detection must not masquerade as prompt detection.

Loch was inspected read-only as an architectural reference. No Loch source/assets were
copied and its working tree was not changed.

See [BUILD_STATUS.md](BUILD_STATUS.md) for budget and verification status.

### Appearance and break music

Choose System, Light or Dark in Small Preferences. The park independently follows
local time: a moon from 7pm to 7am, and a moving daytime sun. During a break,
**Play something peaceful** chooses an original local piano-like loop; **Mute music**
stops it. Nothing plays automatically, and closing the break stops playback.
Streaming playlists and bedtime reminders remain future ideas.

## Launch and future direction

See [the launch plan](docs/LAUNCH_PLAN.md) for positioning, draft posts and the video
storyboard, and [the companion roadmap](docs/COMPANION_ROADMAP.md) for proposed
return cards and explicitly authorized agent recaps. These are plans, not shipped features.
