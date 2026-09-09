# HowFried — bounded MVP product requirements

Status: proposed build contract, ready to use as a goal.
Date: 9 September 2026.
Target: a local macOS prototype for its owner, not an App Store release.

## 1. Product and outcome

HowFried is a quiet desktop companion that observes supported AI activity and reminds its user to step away. A golden retriever signals an upcoming break with paw prints pacing beside the Mac notch, then enters from the bottom-left corner and leads into a five-minute park overlay.

The MVP succeeds when real Claude Code and Codex prompt events feed the same local counter, a selected threshold triggers the warning and break sequence, and the user can reliably snooze or escape. One pet, one screen, one break sequence.

It measures observed AI activity, not cognitive fatigue, attention, addiction, or medical risk. “Fried” is playful language. A break overlay does not suspend agents or prevent token spending.

## 2. Hard delivery constraints

### Implementation budget

- Maximum: **60,000 agent tokens and 4 hours elapsed wall-clock time**, whichever comes first, for the initial build goal.
- This is a bounded prototype budget, not a promise of production readiness. Reused code may still require adaptation.
- Count all implementation, research, debugging, validation, and reporting toward the limit. If delegation is later explicitly authorized, its usage also counts; otherwise use one agent.
- Start the timer when the build goal starts. Do not reset it on retries, restarts, compaction, or provider changes.
- At 45,000 tokens or 3 hours: freeze features. Complete the critical path, validate, and prepare handoff.
- At 54,000 tokens or 3 hours 40 minutes: stop optional fixes and reserve the remainder for safe shutdown and reporting.
- At either hard limit: stop implementation and tool activity after any immediately necessary safe shutdown. Report partial completion and the remaining failures. Do not claim success or extend the budget automatically.
- If the goal runner provides enforceable token accounting, use a 60,000-token goal budget. Report its measured usage. Otherwise explicitly state that token enforcement is unavailable; do not invent an exact token count. Enforce the elapsed-time cap independently using clock checks between work chunks.
- Check time at phase boundaries and at least every 15 minutes. Do not start a command whose timeout would extend beyond the remaining deadline.
- This document does not start a goal or authorize background runs. The owner will initiate the build separately.

### Phase ceilings

These are stop-and-reassess checkpoints, not extra allowances.

| Phase | Token allocation | Time allocation | Required output |
|---|---:|---:|---|
| Inspect reusable code and scaffold | 6,000 | 25 min | Compilable app skeleton and dependency choices |
| Shared events and two prompt adapters | 16,000 | 65 min | Synthetic event tests and integration instructions |
| Break engine and minimal controls | 10,000 | 40 min | Deterministic threshold/countdown/snooze behaviour |
| Paw warning and pet overlay | 14,000 | 55 min | One complete visual sequence |
| Validation, fixes, handoff | 14,000 | 55 min | Test evidence, local artifact, honest status |

Spend no more than 20 minutes on one integration blocker without choosing a documented fallback. Allow at most two substantive repair attempts for the same failure before reporting it and progressing elsewhere. No endless aesthetic refinement, dependency migrations, alternate frameworks, or broad test sweeps.

## 3. Platform and reuse decision

- Native SwiftUI + AppKit, macOS 14 or later; validate on the available local Mac.
- Standalone HowFried project in this directory.
- Read-only reference: the owner’s separate Loch checkout (local-only reference).
- Reuse small relevant pieces only after inspecting their dependencies and applicable license notices: notch geometry/masking, provider payload mapping, and usage parsing.
- Do not edit Loch, move its files, reset its checkout, or depend on its installed app running. It contains uncommitted work.
- Do not import its approval responder, command execution controls, clipboard, music, dictation, media, browser companion, or unrelated plugin system.
- No third-party runtime dependencies unless a concrete blocker makes one necessary and it fits the budget. Use native drawing and animation for the first pet.
- MVP support is limited to the primary display. On displays without a notch, use a small top-centre indicator. Other displays remain usable.

## 4. Included and excluded scope

### Included

1. Menu bar app with a small settings/popover interface.
2. Explicitly enabled prompt integration for Claude Code and Codex local runtimes.
3. One shared event ledger with deduplication and provider attribution.
4. Prompt-count and elapsed-session break triggers.
5. Claude local token threshold only if its existing parser passes fixture validation within the adapter phase; see the fallback below.
6. Pacing paws beside the notch, one illustrated golden retriever, one park backdrop, countdown, optional short native sound.
7. Snooze, visible dismissal, configurable global escape shortcut, tracking pause, and manual “Preview break.”
8. Today’s observed prompt counts, available token totals, and completed/skipped breaks.

### Explicitly excluded

- Cats, breed selection, photorealism, Blender, generated video, commissioned assets, and animation asset pipelines.
- Windows/Linux builds, browser extensions, mobile apps, cloud agents, remote machines, multiple-monitor overlays.
- Reading chats, writing prompts from the notch, approval controls, cancelling agents, or enforcing provider spending caps.
- Accounts, sync, analytics, backend servers, billing, subscriptions, websites, public deployment, App Store packaging, notarization, and auto-update.
- Automatic meeting detection, accessibility surveillance, keyboard-content capture, screenshots, and network interception.
- Universal provider coverage, precise attention tracking, fatigue scores, cost forecasts, subscription-limit conversions, and historical transcript dashboards.
- Automatic launch at login. Launch manually for this prototype.

## 5. Provider contract and coverage

Build a provider-neutral event core. Provider-specific logic must stay inside adapters, never inside the countdown or pet view. Identify the client/integration separately from the model name; detecting an editor process does not prove AI usage.

| Integration | Required MVP signal | Optional signal | Explicit limitation |
|---|---|---|---|
| Claude Code local | Prompt submitted via hook | Token deltas from local usage records | Token coverage is this machine only; not authoritative billing |
| Codex local | Prompt submitted via hook | None required | Installed desktop/CLI compatibility must be tested separately |
| Synthetic demo adapter | Deterministic prompt and usage events | Session events | Always visibly marked Demo; excluded from real totals |
| Future providers | Adapter extension point only | None | No claim of implemented support |

Codex token accounting is out of scope for this build. Do not attach to undocumented desktop internals or parse its transcripts to rescue this feature. Do not equate usage-limit percentages with tokens.

Claude token fallback: if compatible records cannot be validated within the phase ceiling, disable the token trigger and label it unavailable. Deliver prompt/time modes and report the missing capability; do not fabricate token estimates from prompt counts.

### Minimum normalized event

- Schema version, source integration ID, session ID, event ID, timestamp.
- Event kind: `promptSubmitted`, `usageReported`; optional `turnStarted` and `turnCompleted` for future adapters.
- Optional model name.
- Usage payload, when available: distinct input, output, cache-read, and cache-write counts, with explicit accounting semantics.
- Usage identity and whether values are deltas or cumulative totals. Adapters convert cumulative snapshots to deltas before aggregation.
- Coverage status: supported, disconnected/stale, unavailable, or demo.

Keep prompt bodies, tool arguments, transcript contents, credentials, and absolute project paths out of persisted events and diagnostic output. If a hook supplies those fields, discard them before persistence.

### Ingestion correctness

- Hooks record metadata promptly and return; the pet app must never block an AI turn while awaiting a break or approval.
- Prefer a private local append-only event spool. No public listeners or network calls are required.
- Preserve every prompt event, rather than sampling a mutable “latest state” file that can lose intermediate prompts.
- Deduplicate by integration + session + stable event identity. Replays after restart must not count again.
- Do not infer prompts from tool calls, process activity, turn starts, or repeated polls.
- Ignore malformed/incomplete records safely; retry incomplete trailing records after they finish writing.
- Simultaneous adapters must not corrupt shared data. Use isolated per-source spools or atomic event writes.
- Keep hook work minimal. If the app is closed, AI work still continues normally.
- Delayed events may update today’s totals, but must not launch an overdue takeover on app startup. Begin a fresh break cycle on launch.
- Use event-driven updates where practical. While running, a fallback poll should process hook events within 2 seconds; token usage may lag up to 15 seconds.
- No historical transcript import. For token mode, establish a baseline at opt-in and observe subsequent complete records.

## 6. Break rules and realistic user limits

The following are configurable prototype defaults, not evidence-based health recommendations. They are separate from the implementation budget in section 2.

Choose **one primary trigger** in this MVP. This avoids ambiguous combined budgets.

| Mode | Default | Allowed setting | Meaning |
|---|---:|---|---|
| Prompt count | 20 prompts | Integer 5–200 | Observed user submissions since the cycle began, across connected prompt adapters |
| Session timer | 60 minutes | 15–180 minutes | Elapsed time after the first observed prompt, regardless of what happens between prompts |
| Claude tokens, if available | 100,000 tokens | 25,000–2,000,000 | Newly observed Claude input + output + cache-read + cache-write tokens, counted once |
| Break duration | 5 minutes | Fixed in MVP | Time after the full break scene appears |
| Warning | 30 seconds | Fixed in MVP | Visible chance to snooze before takeover |
| Snooze | 10 minutes | Fixed in MVP | Defer this break without erasing the exceeded threshold |

Why 100,000 tokens: this is a starting preference for total processed context, not 100,000 newly typed/generated words. Long contexts and cached inputs can cross it quickly. Explain this beside the control. Do not call it a financial budget or convert it into a prompt equivalent.

Prompt/time modes are the reliable initial defaults. Default selected mode is prompt count. Token mode must say “Claude only” and expose the counting breakdown; missing provider usage is never displayed as zero measured usage.

### Cycle behaviour

- First observed prompt starts a cycle. Counts persist through normal event ingestion; switching selected mode starts a fresh cycle after an explicit UI action.
- Timer mode is deliberately elapsed-session time. No grace-period or attention inference in this MVP.
- At prompt/token threshold crossing, latch a pending break and start a 30-second warning. It is not possible to predict a token burst 30 seconds in advance.
- In timer mode, warn during the final 30 seconds before the configured interval ends.
- Further events during warning/snooze update daily totals but cannot create additional overlays or extend the current warning.
- Completing a break clears the cycle and waits for the next prompt. Daily totals remain intact.
- “Skip this break” clears the cycle and records a skipped break. Snooze retains the pending break, then repeats the 30-second warning after 10 minutes.
- Pausing tracking clears the pending cycle and dismisses warning/overlay. Resuming waits for a fresh prompt. Explain that events during pause are excluded.
- On system sleep/lock, hide the overlay. On resume/unlock, clear any pending cycle and wait for a fresh prompt; no surprise takeover.
- Use monotonic elapsed time for live countdowns and wall-clock timestamps for the local daily summary.
- If the app quits during a break, quitting works immediately. A restart does not resume a blocking overlay.

## 7. User experience

### First launch

One compact setup screen: explain local observation, choose prompt/time mode, select supported integrations, and preview the pet. Token mode appears only when available. No lengthy onboarding, account, or permissions unrelated to selected features.

Show each adapter’s status independently: not configured, awaiting first event, receiving events, or error. “Configured” must not imply a real event has been verified.

### Menu bar popover

- Current state and progress toward the selected threshold.
- Today’s prompts by integration, available token total with coverage label, breaks completed/skipped.
- Trigger selector and numeric limit.
- Enable/disable sound, change escape shortcut, pause/resume, preview break, quit.
- Provider setup instructions and a short last-event/connection diagnostic without content.

### Pacing paws

- Quiet state stays hidden or occupies minimal menu bar space.
- Warning gently extends dark wings to the left and right of the notch.
- Paw prints traverse left to right and back in a loop. They disappear through a masked central region so the notch appears to hide them.
- Respect the measured notch dead zone; never place essential text or controls under it.
- On a display without a notch, render the same motif around a small dark top-centre capsule.

### Pet entrance and park

- Maximum entrance animation: 6 seconds.
- One friendly, recognisable illustrated golden retriever enters from the primary display’s bottom-left corner.
- Follow a short curved zigzag path; scale down and adjust a soft shadow to suggest depth.
- A simple grass/park backdrop grows into a primary-display overlay.
- Headline: “Your tokens can wait. Time for a walk.”
- Begin the five-minute countdown once the park scene is established. Keep subsequent motion minimal.
- Sound off by default; use an available short system sound if a bark asset is unavailable. Do not create an audio production dependency.
- Prefer legible and complete animation over realistic anatomy. Native shapes are acceptable for this prototype.

### Escape and accessibility

- Always-visible “Snooze 10 min” and “Skip this break” controls on the full overlay.
- Configurable global dismissal shortcut; propose Control–Option–Command–B, check registration failure, and display the actual binding.
- Escape dismisses when the overlay has keyboard focus. Do not claim Escape is globally registered.
- Menu bar Quit remains available. No kiosk behaviour or attempts to prevent app switching.
- Standard keyboard focus and accessibility labels for controls, readable contrast and scalable text.
- With Reduce Motion enabled, replace the moving entrance with a short fade and a static pet. All controls remain available.
- If the global shortcut cannot register, surface the error and retain visible dismissal controls.

## 8. Architecture and persistence

Keep four small boundaries:

1. **Adapters:** interpret source events and optional usage records.
2. **Activity store:** validate, deduplicate, persist metadata, aggregate today's observations.
3. **Break engine:** pure state transitions for waiting, tracking, warning, break, snoozed, paused.
4. **macOS presentation:** menu bar, notch warning panel, full overlay, sound, shortcut.

Use injected clocks and synthetic events for core tests. UI drawing must not own usage accounting. Provider code must not decide when the dog appears.

Persist settings, deduplication/checkpoint data, and a bounded local activity window. Retain at most seven days of metadata through logical compaction of the app-owned store; respect the user's no-deletion policy and do not introduce cleanup commands that delete files. Avoid retaining every animation tick or duplicating transcripts. Daily rollovers follow the Mac’s current local date.

A straightforward local store is enough. No database framework evaluation or plugin marketplace architecture. Keep extension points small and explain how a future adapter would supply events.

## 9. Installation and change control

- Building source in HowFried is separate from modifying provider configurations.
- Prepare complete, reviewable hook snippets and setup instructions first. Preserve existing hooks and settings.
- Do not automatically write to Claude/Codex user configuration, install the app globally, grant permissions, change startup settings, or publish anything during the build goal.
- Where explicit approval is needed for a real integration test, state the exact configuration file, added operation, and effect. A missing approval is not a reason to pretend synthetic testing proved live support.
- Provide manual additive setup instructions when configuration changes are not authorized. Do not run upstream scripts that delete files, replace configs, or alter unrelated apps.
- Do not launch agents or paid API requests simply to generate test usage. Prefer a user-submitted prompt once setup is authorized.

## 10. Acceptance criteria

### Core correctness — required

- [ ] Clean local build produces a launchable macOS app using documented commands.
- [ ] Synthetic Claude and Codex submissions flow through their real parsing paths into the same counter.
- [ ] Duplicate events and replay after restart do not increase counts.
- [ ] Two distinct rapid submissions are both counted; tool events never increment prompt counts.
- [ ] Malformed and partially written input cannot crash the app or trigger a break.
- [ ] Prompt threshold triggers exactly one warning, then one break.
- [ ] Timer warning and break deadlines behave correctly with an injected clock.
- [ ] Snooze, skip, pause, completion, restart, and sleep/resume follow section 6.
- [ ] No prompt body or tool argument is present in persisted test events or diagnostics.

### Presentation — required

- [ ] Paws cross both notch wings, with no essential content in the central dead zone.
- [ ] Dog entrance, grass scene, headline, and countdown form one complete sequence.
- [ ] Snooze, skip, and successfully registered global shortcut dismiss reliably.
- [ ] No-notch fallback and Reduce Motion work in preview/test configuration.
- [ ] No modal window traps the user or prevents quitting.

### Token mode — conditional, never silently faked

- [ ] Known fixture totals match input/output/cache accounting exactly.
- [ ] Cumulative snapshots/repeated records do not double count.
- [ ] Threshold is based on usage after opt-in/cycle baseline.
- [ ] UI says Claude-only local coverage and explains cached-token counting.
- [ ] If validation fails within budget, token mode is unavailable and this is reported.

### Live integration evidence — report separately

- [ ] One owner-authorized real Claude Code prompt observed.
- [ ] One owner-authorized real Codex prompt observed, with tested client identified.
- [ ] Real events affect the correct counters without storing prompt contents.

If live setup is not authorized or the relevant client is unavailable, deliver the runnable prototype plus setup instructions and mark live verification pending. Do not mark the entire MVP fully verified. Do not keep a goal running waiting indefinitely for an external prerequisite; follow the configured budget and the goal runner’s status rules.

## 11. Test and iteration limits

Use focused tests for the shared engine, adapter parsing/deduplication, and token parser if included. Use synthetic files in an isolated app-owned test directory. Inspect build/test scripts before executing them; avoid any destructive cleanup.

Perform one focused automated pass and one manual UI pass, then rerun only checks affected by actual fixes. Avoid unrelated Loch tests and release preflight scripts. Visual acceptance is functional and recognisable, not polished marketing art. Maximum two visual refinement passes.

Do not add a dependency, major subsystem, or new provider to get a single optional test green. Record a limitation instead.

## 12. Deliverables and finish line

1. Source and local runnable app artifact, with reproducible build instructions.
2. README with setup, supported coverage, shortcuts, privacy, and known limitations.
3. Additive provider hook examples; no automatic global configuration changes.
4. Focused tests and a validation report distinguishing synthetic, visual, and real integration evidence.
5. Final budget report: elapsed time, measured agent tokens if available, completed scope, skipped scope, and outstanding acceptance criteria.

Finish once the required acceptance criteria pass, or stop at the hard budget with a concrete partial handoff. Optional token mode and aesthetic improvements must not extend the goal. No public deployment, extra providers, second pet, or ongoing autonomous work belongs to this goal.

## 13. Goal prompt to paste

> Build the HowFried local macOS MVP defined in MVP_PRD.md. Use that document as the scope and acceptance contract. Work only in this HowFried project; inspect Loch read-only and reuse only narrowly relevant components with applicable notices. Use one agent. Maximum build budget: 60,000 agent tokens and 4 elapsed hours, whichever comes first. Freeze features at 45,000 tokens or 3 hours and reserve the final budget for validation and handoff. If token accounting is unavailable, disclose that and enforce the wall-clock limit; do not fabricate usage figures. Implement the shared event core, Claude Code and Codex prompt adapters, prompt/time break rules, one golden retriever, pacing notch paws, and the five-minute escapable break overlay. Claude token mode is conditional on validated local accounting within the adapter budget; Codex token accounting is excluded. Prepare provider configuration changes for review without applying them unless separately authorized. Never change Loch or run destructive commands. Validate with synthetic fixtures and report live verification separately. Stop when required criteria pass or either budget expires; deliver the runnable result or an honest partial handoff with exact remaining blockers. Do not expand scope, publish, create automations, or continue indefinitely.
