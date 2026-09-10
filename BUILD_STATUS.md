# Build status and budget

The owner authorized an additional **40,000 tokens** after the initial build stopped.
Initial goal accounting stopped at **67,755 tokens**. The goal API still reports
`blocked`; its API cannot resume it or edit its token limit. Do not create a replacement
goal or reset the original wall-clock deadline to work around this.

Original start: 2026-09-09 10:16:19 UTC. Original deadline: **14:16:19 UTC**.
Continuation authorized and started: approximately **10:33 UTC**.
If live goal accounting resumes, the continuation hard ceiling is **107,755 total
tokens**. Otherwise treat 40,000 additional tokens as the manual work budget,
check time regularly, and do not claim an exact measured continuation count.

No scope expansion: compile fixes, focused tests, local packaging, UI verification,
setup documentation, and remaining correctness fixes only. Live provider configuration
changes still require separate authorization. No changes to Loch.

## Current handoff

**Runnable local prototype; live provider verification is pending.**

Final bundle: `artifacts/20260910T094441Z-59118/HowFried.app`.
Built with Swift 6.3.3 on arm64 macOS 26.6.2, targeting macOS 14+. This is a local
ad-hoc-signed build, not a notarized or universal distribution artifact.

`swift test` passes **21 focused tests**, zero failures. Latest test log:
`.qa/refinement-tests-final.txt`. Release build and `codesign --verify --deep --strict`
both succeed. The script preserves previous build artifacts.

### Evidence against the PRD

| Requirement | Evidence / status |
|---|---|
| Local launchable app | Final release bundle builds and launches; menu-bar dashboard inspected |
| Two prompt adapters, one counter | Packaged hook fed five synthetic submissions into running app: Claude 3, Codex 2; exactly one warning at 5/5 |
| Deduplication and restart | Ledger replay/reopen tests pass; explicit event IDs dedup; absent IDs use invocation UUIDs |
| Rapid prompts and concurrent writers | Distinct submissions and 12 concurrent SQLite connections tested |
| Tool/malformed/partial events | Parser rejection tests pass; hook returns no instructions or decisions |
| Content-free storage | Synthetic prompt/tool secrets absent from serialized events and database bytes |
| Prompt/time rules | Injected-clock tests cover threshold, warning deadline, entrance, full break duration, snooze, skip, pause and reset |
| Claude token parser | Fixtures validate cache/input/output sums, cumulative-to-delta conversion, replay, baseline, partial records, oversized-record recovery and resumed-period exclusion |
| UI entrance and countdown | Captured native dog entrance and park countdown; fixed a runtime transition failure found in the first visual pass |
| Walking paws | Changed from sliding icons to alternating planted/fading footprints per owner feedback; position/alternation/fade/reversal test passes; native warning captured |
| Attached notch shape | Read Loch's UI guidelines as design reference; original top-flush shape with inward shoulders and lower rounding. Runtime: topFlush=true, height=33 points, width=585 points, dead zone=185 points; approximately 200-point wings. Screenshot/video verified; all content clipped to the shape |
| Visible dismissal | Preview Snooze returns to dashboard with totals unchanged; Escape on a threshold-triggered overlay records one skipped break |
| Shortcut | Carbon registration succeeds with default binding; actual global invocation from another app still needs a human check |
| Reduce Motion | Forced QA environment verified static pet/fade, running countdown and successful preview completion |
| Display behaviour | Primary-screen overlay and notch warning inspected; no-notch code path exercised by QA. Full-screen Spaces, physical display hotplug and other hardware remain unverified |
| Dock overlap | Overlay raised above Dock/below menu bar, controls inset by at least 96 points; final recording shows clear dismissal controls |
| Quit | Quit button terminates the app cleanly (observed process exit 0) |
| Sleep/lock | Notification wiring and engine reset exist; actual Mac lock/sleep transitions were not induced during testing |
| Daily totals/retention | Local calendar boundary and seven-day logical retention tests pass; no filesystem cleanup |
| Live Claude / live Codex | **Not performed.** Provider configs untouched; owner-submitted prompts required after additive hook setup/trust |

### Remaining limits

- Basic hook payloads do not guarantee a unique submission ID. Two separately invoked
  duplicate hooks can overcount, so install HowFried once per provider. A Codex turn ID
  is deliberately not used as a submission ID, because steering can share a turn.
- Token numbers cover newly observed local Claude records only, not billing, all devices,
  or exact generation time. Live compatibility with the owner's Claude version is unverified.
- The pet is an original simple vector puppy with short alternating paws, a rounded belly,
  wagging tail and a crossfade into its seated pose. No extra pets/providers were added.
- Notification-based sleep/lock integration and the shortcut require the manual checks
  above before claiming the entire PRD is fully verified.

### Captures

- `.qa/howfried-animation.mp4`: approximately 11 seconds, sampled native app-window
  capture of the dog entrance and park. Preview timer accelerated 6× in the test environment;
  entrance itself remains five seconds. No other desktop applications were recorded.
- `.qa/howfried-notch-final.mp4`: latest native warning-panel capture, with attached top edge, physical-notch-height body, wider wings and alternating footsteps.
- `.qa/howfried-paws.mp4`: earlier footstep capture, superseded by the final notch clip above.
- `.qa/animation-frames/0036.png`: final park with Dock-safe controls.
- `.qa/reduced-motion.png`: static-pet accessibility preview.

### Budget / scope

Initial measured goal usage remains **67,755 tokens**, including the previously reported
overrun. The goal API stayed blocked and its counter did not advance during this continuation;
**exact continuation token usage is unavailable**, so no exact total is claimed.
Continuation work began about 10:33 UTC and reached this handoff about 10:59 UTC, within
the original 14:16 UTC deadline. The added budget was used for compile fixes, validation,
packaging, documentation, the requested recording, and the owner's targeted paw feedback.

Loch, provider configuration, trust settings, login items and system permissions were not
changed. No paid AI calls were made for testing. No deployment or background automation
was created. Do not treat the unverified items above as complete.

## Latest owner-requested refinements · 13:07 UTC

- Paws remain wholly inside visible wings, with a one-second invisible notch crossing
  and restrained outward splay (24–32 degrees). Geometry and crossing tests pass.
- Shortened the puppy body and limbs, enlarged its head, added a soft belly and
  reduced stride/bounce after visual feedback on the initial side-on silhouette.
- Dashboard appearance: System / Light / Dark, persisted locally.
- Park uses local clock: moon from 19:00–07:00; daytime sun follows an arc.
  This is clock-based art direction, not actual astronomical sunset.
- Explicit Play / Mute for three original local piano-like loop variants; no network,
  account integration or autoplay. Playback stops when the overlay disappears.
  AVAudioPlayer startup and mute verified in QA with output volume held at zero;
  subjective listening quality remains unreviewed.
- Session time remains elapsed time after the first prompt, including gaps. Prompt
  rules count submissions across enabled providers; live hook setup remains pending.
- Spotify/Apple Music playlist selection and optional bedtime reminders are deferred.
  No automatic shutdown/sleep or strict agent token enforcement was added.

Latest visual evidence: `.qa/howfried-round-puppy.mp4` (native sampled entrance and
night park), `.qa/howfried-paws-compressed.mp4` (warning), `.qa/dark-dashboard.jpeg`.
Earlier walking-dog recordings are superseded. Preview countdown is accelerated in
QA; the entrance remains five seconds. App preview closed after inspection.

Sitting-pose refinement: matched walking puppy coat, head height, eye highlights,
blush, short paws and rounded belly. Both poses use the same canvas and frame dimensions
to avoid growing at the transition. Dashboard uses the updated puppy too. Release
build and signature verification pass; native preview inspected and closed. Latest
capture: `.qa/howfried-matching-puppy.mp4`. No tracking logic changed.

10 September: added native status menu (Open, Skip, Quit), fixed dashboard Quit footer,
build date label and equal-width break actions. Release/signature checks pass; native
dashboard and preview controls inspected; pinned Quit exits cleanly. Two older owner
builds were found running; they were not terminated by this QA run. Actual cross-app
dismissal and menu-bar access during the overlay still need a hardware check.

Latest refinement: warm charcoal dashboard, editable 1–200 prompt threshold, and one
physical pixel of top-edge overscan on the notch panel. 22 tests pass including one
submission triggering warning. UI verified entering 1; final Apply verification was interrupted by owner interaction. Live provider hook
verification remains pending. Physical seam needs owner display confirmation.

## Public-source handoff

Codex live delivery subsequently verified: one real submission stored after user
trusted the HowFried hook. Codex observation enabled with permission; existing hook
preserved and private backup created. Earlier pending/untouched statements above
are historical. Claude live delivery remains unverified. Latest setup-prompt bundle:
`artifacts/20260910T101344Z-64220/HowFried.app`. README is the public capability summary.

## Developer ID release · 10 September

Version 0.1.0, Apple Silicon, macOS 14+. Fresh build signed with Developer ID and
hardened runtime, including the bundled hook. Apple notarization accepted; ticket
stapled and validated. Gatekeeper accepted both original and ZIP-extracted app as
Notarized Developer ID. Final local archive:
`artifacts/20260910T102534Z-65439/HowFried-0.1.0-macos-arm64.zip`.
SHA-256: `1ceb5a3725b71cc9e116087e0ca527260eb49f2f42dacdf937ef89f67c39b216`.
No binary uploaded to GitHub Releases yet. No Homebrew tap created.
