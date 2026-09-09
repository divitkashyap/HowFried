# Owner checks before relying on reminders

The app and synthetic pipeline are working. These checks require the owner's actual
environment and were not silently replaced by fixture tests.

1. Follow SETUP.md to append one hook handler to each selected provider's existing
   settings. Review/trust it in that client. Send a normal prompt yourself. Confirm
   exactly one increase in that provider's count. Check Codex desktop and CLI separately.
2. Start Preview break. From another app, press the displayed global skip shortcut.
   Confirm that the preview disappears. Try another combination if registration fails.
3. Start a preview, then lock/unlock the Mac. Confirm the overlay stays dismissed and a
   fresh real prompt is required before another cycle. Repeat for sleep/wake if desired.
4. Check the primary display while using a full-screen app or another Space. Confirm
   the warning/overlay appear where expected, the Dock does not hide the buttons, and
   menu-bar Quit remains available. Other displays are intentionally not covered.
5. Before using Claude token mode, opt in and observe your next ordinary session. Compare
   the local usage trend with Claude's own reported usage, remembering that cached inputs
   are included and that subscription percentages are not token totals.

No check requires an agent to launch extra paid requests. Use the visible Skip button or
Quit if any overlay behaviour is inconvenient. Report an unsupported environment as such;
do not claim universal compatibility.
