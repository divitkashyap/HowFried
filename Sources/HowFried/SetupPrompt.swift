import Foundation

/// Self-contained setup instructions tied to the running bundle, not a private URL.
enum SetupPrompt {
    static func text(provider: String) -> String {
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/howfried-hook").path
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = quoted + " " + provider
        let group: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 2]]]
        let data = try! JSONSerialization.data(withJSONObject: group, options: [.prettyPrinted, .sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        let destination = provider == "codex" ? "~/.codex/hooks.json" : "~/.claude/settings.json"
        let review = provider == "codex" ? """
        REQUIRED MANUAL CODEX STEP: Tell me to open the Codex CLI/TUI on this same Mac using the same Codex configuration as my desktop app (run `codex` in a terminal), then enter `/hooks`. Under UserPromptSubmit, find the exact entry whose command contains `howfried-hook codex` at the executable path above. Ask me to review and accept/trust that HowFried hook, and ensure it is enabled. Do not ask me to trust unrelated hooks. Adding hooks.json is not sufficient: Codex skips new or changed untrusted definitions. Do not edit trust hashes or bypass hook trust for me. If the entry is missing, check the configuration source and refresh/reopen the CLI; do not add a duplicate. A changed command or app path may require review again. Do not claim setup is complete until I have accepted the hook and a real submission from my intended client reaches HowFried.
        """ : """
        MANUAL CLAUDE STEP: Tell me to open Claude Code and inspect `/hooks` for the HowFried UserPromptSubmit command. Follow any review, enablement or reload prompts shown by my installed client. Do not assume Codex's trust mechanism applies to Claude or approve unrelated hooks. Verify a real Claude submission before declaring success.
        """
        return """
        Help me connect HowFried to \(provider). First explain the exact changes and obtain my permission before modifying my agent configuration.

        Verify the local executable exists: \(executable)
        Inspect \(destination) without printing unrelated settings or secrets. Preserve all existing hooks and settings, make a private timestamped backup, and append the following group to hooks.UserPromptSubmit only if HowFried is not already installed. Never replace the entire hooks array. If an existing HowFried hook uses another path, explain the update instead of adding a duplicate. Stop on invalid JSON or an unsupported hook format.

        \(json)

        This local hook counts user submissions; it does not save prompt text or return agent instructions. Do not send synthetic events into my real activity database. Do not change trust settings automatically.

        \(review)

        Ask me to enable observation for \(provider) in HowFried, set the prompt limit to 1 and Apply, then send one real prompt. Verify the counter changes before calling the connection working. Applying a limit alone does not install a hook. Keep the app bundle at this path while connected.
        """
    }
}
