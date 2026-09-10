# Connect your local AI tools

HowFried observes `UserPromptSubmit` hooks. It never asks the agent to call a tool,
injects instructions, handles approvals, or stops generation. These instructions are
manual: the app does not modify provider settings.

## Before changing configuration

1. Build the app with `bash scripts/build.sh` and launch the returned app path.
2. Enable observation for your selected provider in HowFried. This initializes its private
   local ledger and permits incoming observations; it does **not** install a hook.
3. Locate `Contents/MacOS/howfried-hook` inside that app bundle. Use its absolute path below.
   Keep the bundle in that location once connected, or update the path after moving it.
4. Review the existing provider hook configuration. Preserve its content and append this
   handler to the existing `UserPromptSubmit` array. Do not replace the entire file.

The snippets are templates. Replace `/ABSOLUTE/PATH/HowFried.app` with the actual bundle
path. Single quotes inside the command protect ordinary spaces in paths. For a path
containing a literal apostrophe, use the snippet generator described below.

## Claude Code

Target: your selected Claude Code settings file, normally `~/.claude/settings.json`.
Add a command hook group under `hooks.UserPromptSubmit`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "'/ABSOLUTE/PATH/HowFried.app/Contents/MacOS/howfried-hook' claude",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

Review or reload hooks using the client's hook settings. Send a prompt yourself and
check that HowFried changes from “Awaiting first event” to “Receiving events.”

The basic submission payload does not guarantee a unique submission ID. HowFried
assigns each invocation an ID, so identical prompts remain distinct. Database/event
replays are deduplicated; two separately invoked hooks for the same submission
cannot always be identified as duplicates. **Install this handler only once.**

## Codex local

Target: the Codex hook configuration for the selected local runtime, normally
`~/.codex/hooks.json`. Use the same additive structure with `codex` as the argument:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "'/ABSOLUTE/PATH/HowFried.app/Contents/MacOS/howfried-hook' codex",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

**Required after adding the Codex hook:** open the Codex CLI/TUI on the same Mac
and configuration as your desktop app (`codex` in a terminal), then enter `/hooks`.
Under `UserPromptSubmit`, review and accept/trust the entry containing
`howfried-hook codex` with your chosen bundle path, and ensure it is enabled.
Accept only the relevant HowFried entry. New or changed definitions are skipped
until trusted; adding JSON alone is not enough. If missing, check the config source
and refresh/reopen the CLI before adding anything else. A changed command/path may
require trust again. Never edit trust hashes or bypass review to complete setup.
Availability depends on the installed client/runtime. Verify CLI and desktop separately;
success in one is not evidence for the other. This prototype does not inspect or alter
Codex trust settings. A Codex turn ID is not treated as a submission ID: follow-up input
can belong to an existing turn. The same invocation-ID limitation described above applies.
An explicit source event ID is used when available; it is not assumed to be provided.

## Generate snippets with the exact bundle path

From the HowFried source directory:

```sh
python3 scripts/hook_snippet.py '/absolute/path/to/HowFried.app' claude
python3 scripts/hook_snippet.py '/absolute/path/to/HowFried.app' codex
```

The script prints JSON only. It does not write configuration or make a network request.

## Optional Claude token observation

Enable Claude prompt observation first, then opt into “Read new Claude token records
locally.” This scans new complete JSONL records under `~/.claude/projects` at ten-second
intervals. Existing bytes are skipped at opt-in. Input, output, cache-read and cache-write
tokens are included; repeated message snapshots contribute only positive deltas.

The number means **newly observed local records**, not a provider invoice or exact token
generation time. A record arriving after opt-in can describe work that began earlier.
Other machines, browser chats and Codex tokens are not covered. A long context can cross
100,000 processed tokens rapidly. The app never estimates tokens from prompt counts.

The local JSONL schema is a compatibility boundary, not a promised stable API. Synthetic
parser tests do not prove compatibility with your installed Claude version. Verify the
counter with your own session before relying on token mode. A missing/quiet source is not
proof of zero usage.

## Disable safely

Turn off provider observation in HowFried to reject new records. You can manually disable
the corresponding hook in the provider's settings. Existing unrelated hooks must remain.
HowFried does not provide a destructive uninstall or configuration-replacement command.

## Sources checked during development

- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)

These describe provider hooks. Live integration with the owner's installed clients is a
separate validation step and has not been performed automatically.
