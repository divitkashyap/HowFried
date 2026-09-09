# Companion roadmap — proposal, not shipped functionality

## Keep the promise small

A friendly break and a gentle return to work. Reward taking the break, not burning
more tokens. Keep HowFried native and event-driven, with no background language model,
continuous screenshots, browser scraping or constant repository scans.

## Next small release: return card without AI

Offer 5 / 10 / 15 minute breaks and an “I'm back” action after the timer. Show break
length, today's observed prompts and optional observed Claude token totals with
coverage labels. These are activity counts, not productivity or health scores.
No artificial “great work” assessment based on volume. Copy: “Welcome back. One
walk taken. Ready when you are.” No extra provider permissions or API spend.

Track observed sessions honestly: recent submission is not proof an agent is still
running. Label “recent sessions” until an integration supplies a trustworthy lifecycle.
A laptop sleep or app restart must not falsely claim completed work during the gap.

## Later experiment: explicitly requested agent recap

The user chooses specific supported sessions and reviews the exact message before
sending. Never broadcast silently to every agent or infer approval from taking a break.
Some clients may not expose a supported way to send or fetch messages; disable the
feature there and offer copyable text. Do not hijack terminals or synthesize Enter.

Draft message:

> I'm taking a short break. At your next safe stopping point, give me a brief recap:
> what changed, checks run, what remains, and any decision you need from me. Keep it
> under 150 words. Do not change your task or do extra work just to produce this recap.

Sending a message can interrupt or steer an active agent. Explain that beside Send;
prefer completed-turn summaries where an API supports them. Do not promise an
uninterrupted recap for every provider. The initial read-only hook adapter cannot
send messages; this requires a distinct capability and review.

Cost/latency guardrails for a prototype: one explicit request per selected session,
maximum three sessions, no automatic retries, no polling more often than every 30s,
stop fetching after two minutes, no persistence after dismissal unless requested.
Use a hard 512-output-token cap only where the provider API actually enforces it;
a word request in chat is not a token limit. If cost or cap is unknown, say so before
sending. Existing tasks may finish later; show “not ready” rather than triggering
extra generation. Never add a new paid API key dependency merely for a recap.

Treat returned text as untrusted display content. No commands, links, or instructions
execute from a recap. Strip active markup, limit each response to 8KB and display at
most three cards. Opt-in response access changes the current metadata-only privacy
promise; disclose scope clearly. Keep raw replies ephemeral, no prompt logging.

## Git statistics are an optional separate connector

Only explicitly selected repositories. Read commit metadata after a break, with no
network calls and no diffs or file contents. Commits are not pushes; do not infer
push counts from local history or attribute every agent commit to the user. Accurate
push reporting requires a trustworthy authorized event source. Keep unavailable
fields absent. Never call git push, commit or other modifying commands for statistics.

## Defer until users ask repeatedly

Spotify/Apple Music playlists, bedtime reminders, more pets, cross-platform builds,
and richer agent controls. Bedtime begins as a dismissible sleepy-puppy reminder;
no automatic shutdown or sleep. Streaming controls need their own supported APIs,
permissions and account behavior. No hidden access to messaging or playlists.

## Bounded validation

Do not implement this roadmap during marketing preparation. Proposed first slice:
return card and configurable duration only, maximum 8,000 implementation tokens and
90 minutes after separate authorization. Recap integration gets a separate feasibility
budget of 4,000 tokens / 45 minutes for one provider, then a go/no-go review. Stop at
whichever limit arrives first and report what's incomplete; do not invent support.
