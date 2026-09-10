# HowFried 🐾

**Your agents have tasks. Your dog has concerns.**

A tiny native Mac companion that reminds you to take a walk between AI prompts.
Paws appear beside your notch, a small golden puppy comes to get you, and your
screen turns into a five-minute park break. Your agents can keep working underneath.

**Open source · MIT · macOS 14+ · Early prototype**

## A little less fried

- **Choose your limit:** 1–200 submitted prompts, elapsed session time, or optional
  observed Claude tokens. Defaults: 20 prompts / 60 minutes / 100,000 tokens.
- **See the warning:** alternating footsteps beside the notch for 30 seconds.
- **Take five:** a tiny puppy walks in and settles into a day or night park.
- **Stay in control:** snooze for 10 minutes, skip, pause, or quit from the menu bar.
- **Keep it quiet:** optional original piano-like loops, off until you press Play.
- **Make it yours:** light, warm charcoal or system appearance; Reduce Motion support.

HowFried counts **user submissions**, not agent replies, tool calls or model loops.
Session time includes gaps after the first prompt; it does not measure attention.
This is a break reminder, not a system lock, spending cap or productivity score.

## Try it from source

A [signed and notarized Apple Silicon preview](https://github.com/divitkashyap/HowFried/releases/tag/v0.1.0) is available. Download the ZIP, quit older copies, and move the app to Applications before connecting hooks. There is no Homebrew package yet.

To build from source, requires macOS 14+
and Apple's Swift toolchain / Command Line Tools. Tested on Apple Silicon; Intel
hardware has not been verified. Windows and Linux are not supported.

```sh
git clone https://github.com/divitkashyap/HowFried.git
cd HowFried
swift test
bash scripts/build.sh
```

The script prints the path to a new `artifacts/<build>/HowFried.app`. Open that bundle
in Finder. Builds are locally ad-hoc signed, not notarized distribution releases.
Quit any older HowFried copies first so multiple versions do not run together.

The paw menu offers **Open HowFried**, **Skip current break**, and **Quit HowFried**.
Closing the dashboard leaves the app running. Use **Preview break** to meet the puppy
without changing real activity totals.

## Connect Codex or Claude Code

**Applying a limit does not connect your AI tools.** Observation starts disabled.

1. In Connections, choose **Copy Codex setup prompt** or **Copy Claude setup prompt**.
2. Paste it into your agent. Review and approve its proposed configuration changes.
   The instructions preserve existing hooks, create a backup and avoid duplicates.
3. **Codex:** open the Codex CLI/TUI on the same Mac/configuration, enter `/hooks`,
   and review/trust the `UserPromptSubmit` entry containing `howfried-hook codex`.
   New or changed hooks are skipped until trusted. Accept only the relevant entry.
   **Claude Code:** review the hook using the installed client's hook settings.
4. Enable observation for that provider in HowFried.
5. Set the limit to **1**, click **Apply & start a fresh cycle**, and send one real
   prompt from the client you intend to use. Confirm the counter advances and warning
   begins, then choose your normal limit.

Prefer manual configuration? See [SETUP.md](docs/SETUP.md) for additive snippets.
Keep the connected app bundle at the same path. Moving it or changing its hook command
requires updating the configuration and may require trusting the new definition.

**Stuck at 0 / 1?** Check observation is enabled, the hook points to an existing
executable, and Codex has trusted the exact definition. Restart/reload the client if
needed. “Awaiting first event” means delivery has not been verified yet. Preview is
not proof that provider integration works.

## Current coverage

| Feature | Status |
| --- | --- |
| Codex submitted prompts | Live local delivery verified after hook trust |
| Claude Code submitted prompts | Adapter tested with synthetic events; live validation pending |
| Token totals | Opt-in new local Claude usage records only; Codex tokens unavailable |
| Desktop coverage | One primary display; external monitors remain usable |
| Warning / break duration | 30-second warning, five-minute break |
| Dismissal | Visible controls; default global shortcut ⌃⌥⌘B; Escape when focused |
| Global shortcut across apps, Spaces, display hotplug | Further hardware checks needed |
| Streaming radio, Spotify, cats, recaps, Windows/Linux | Not implemented |

A real Codex submission has reached the local counter. That does not establish
compatibility with every Codex version, host or remote task. Token totals are partial
observations, include cache usage, and are not billing-grade data.

## Local by design

SwiftUI + AppKit, SQLite, original vector artwork and synthesized music. No third-party
package dependencies, accounts, servers, telemetry SDKs or background AI requests.

Data stays in `~/Library/Application Support/HowFried/activity.sqlite`: hashed event
and session identities, timestamps, provider labels, optional token counts, settings
and break outcomes. No prompts, replies, tool arguments, credentials or project paths
are stored. The optional Claude scanner reads local records in memory and discards
conversation content. Records have seven-day logical retention.

The hook returns no agent instructions or approval decisions and fails open if
observation is unavailable. Duplicate installations can overcount; install once per
provider. Missing/invalid events can be dropped. Agents continue during breaks.

## Development and contributions

Run `swift test` and `bash scripts/build.sh`. Tests use synthetic data; please do not
attach real conversations, tokens or configuration files to issues.

For isolated manual testing, set `HOWFRIED_DATA_DIR` to an empty local directory when
launching the executable. `HOWFRIED_QA=1` accelerates preview countdowns only and mutes
audio output. See [manual checks](docs/MANUAL_CHECKS.md).

- `Sources/HowFried`: dashboard, notch, overlay, puppy and audio.
- `Sources/HowFriedCore`: event adapters, local store and break state machine.
- `Sources/HowFriedHook`: bounded, quiet submission observer.
- `Tests/HowFriedCoreTests`: parsing, privacy, counter, timing and geometry checks.

Small focused contributions are welcome. For new providers, emit normalized events
through a separate adapter and declare unavailable signals honestly. For large changes,
open an issue first. Good next areas: multi-display behavior, onboarding, accessibility
and a tested release workflow. A Windows port requires a new platform layer; this SwiftUI/
AppKit app cannot simply be packaged as a Windows executable.

[Companion roadmap](docs/COMPANION_ROADMAP.md) · [Launch ideas](docs/LAUNCH_PLAN.md)

## License

[MIT](LICENSE). Original project code, puppy artwork and synthesized music are included.
