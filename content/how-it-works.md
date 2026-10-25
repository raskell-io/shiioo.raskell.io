+++
title = "How it works"
description = "One rule, and what follows from it: the per-run event log is the only state. How runs survive crashes, how Claude Code and Codex are driven, how the rules and your approvals gate every command, and how capacity is routed."
[extra]
eyebrow = "Background"
toc = true
next = { title = "Design", url = "/design/" }
+++

## One rule

Every run has an append-only, hash-chained event log, and that log is the only state. Workers hold nothing they cannot rebuild from it. Live streams, crash recovery, the audit trail, the phone's status line: all of them are reads of the same log. When a design question comes up, the first question is "which events does this write, and who may write them?"

A run's log, as `shiioo log` prints it:

```text
#0   run created: Run the shell command `date` and reply with its exact output.
#1   lease acquired by local-93021 (epoch 1)
#2   claude-code session 9d553561-e665-493c-aea2-84eedd95d623 (claude-haiku-5-5)
#3   claude-haiku-5-5:
#4   → Bash {"command":"date","description":"Print current date"}
#5   capacity claude-code: 5h 32%, 7d 5% used
#6   rules: ask Bash (default: ask)
#7   waiting for approval: Bash: date
#8   allow by owner
#9   ← Sun Oct 25 08:03:19 CET 2026
#10  claude-haiku-5-5: Sun Oct 25 08:03:19 CET 2026
#11  harness result: success, cost $0.0000, 0 permission denial(s)
#12  completed: Sun Oct 25 08:03:19 CET 2026
chain verified: 13 events
```

| Line | What it records |
|---|---|
| #0 | The run is created with its task. |
| #1 | A worker takes the lease; the epoch is in the event. |
| #2 | The harness starts and reports its session id and model. |
| #3 | The model's first response, recorded before anything in it runs. |
| #4 | The tool call the model wants: `Bash`, with its arguments. |
| #5 | The subscription windows the harness reported, kept for routing. |
| #6 | The hook asked the office; the rules said ask, by the default. |
| #7 | The request went to the phone. |
| #8 | The owner allowed it. |
| #9 | The command ran; its output. |
| #10 | The model's final answer. |
| #11 | The harness's own result: outcome, cost, permission denials. |
| #12 | The terminal event. The run is closed; nothing can be appended after it. |

Every line is an event. Nothing in this view was reconstructed from anywhere else.

## The event

Each event carries its position in the run (`seq`, contiguous from 0), the lease epoch it was written under, a timestamp, a schema version, the hash of the previous event and its own SHA-256. The hash is computed over the event's stored bytes, not a re-encoding, so an event written today still verifies under any future build, and any change to the bytes, even whitespace, is detected. `shiioo log` ends with `chain verified` or `CHAIN BROKEN`.

## Leases and fencing

Exactly one worker may append to a run at a time. A worker takes a lease with a time-to-live and renews it in the background; every lease grant gets a strictly higher epoch than any before it for that run, and every write names its epoch. The store checks the epoch inside the same transaction as the write.

That is what makes a stalled worker harmless. If a worker pauses (a sleeping laptop, a stuck network) and its lease expires, another worker takes over with a higher epoch. When the first one wakes up and tries to write, it is fenced: the store refuses, the worker stops and discards whatever it was doing. Takeovers are themselves events (`lease acquired … (epoch 2)`), so the log shows them.

## Write before acting

The model's response is recorded before any tool in it runs. Before a tool call executes, its intent is recorded, with a class: pure (reading a file), idempotent (writing the same content to the same path) or side-effecting (a shell command, a push, a payment). After it executes, the result is recorded.

A crash can therefore leave a log that says exactly what was and wasn't done. A pure or idempotent call with no result is simply run again. A side-effecting call with no result is never retried blindly: the worker that takes over asks the machine's journal whether the call ran. If it finished, the journaled result is recorded; if it never arrived, it runs now; if it started and nobody knows, the run stops with `needs attention` and tells you. The test suite kills a worker at every point of a turn and checks that a "charge the card" tool ran exactly once; a seeded simulation does the same over thousands of scenarios with crashes, lease races and machine restarts.

## Employees

Shiioo's employees are the coding agents you already pay for, run headless:

- **Claude Code** is started as `claude -p "<task>" --output-format stream-json` in the run's git worktree. Every line it prints (its session id, each model message, each tool call and result, its rate-limit windows, its final result) becomes an event. Its environment is scrubbed of any `ANTHROPIC_API_KEY`, because in this mode Claude Code would prefer the key over your login and bill API credits.
- **Codex** is started as `codex exec --json` the same way, and resumed with `codex exec resume <thread>`. `OPENAI_API_KEY` is removed for the same reason. Codex's own OS sandbox is off: headless Codex cannot ask for an exception, and its workspace sandbox makes the checkout's git directory read-only, so an agent inside it could never commit. Shiioo's rules govern its commands instead.
- **Local models** (Ollama, LM Studio, MLX servers) serve Shiioo's own agent loop, named like `ollama/qwen3:32b`.

What each harness is given:

| | Claude Code | Codex |
|---|---|---|
| Start | `claude -p <task> --output-format stream-json --verbose` | `codex exec --json <task>` |
| Resume | `claude --resume <session>` | `codex exec resume <thread>` |
| Rules hook | On every tool call; only the project's settings are loaded | On `Bash`/`shell` commands; file edits are recorded but not gated |
| Removed from its environment | `ANTHROPIC_API_KEY` and the parent session's `CLAUDE*` variables | `OPENAI_API_KEY`, `CODEX_API_KEY` |
| Its own permission prompts | `--permission-mode default` with the hook, `acceptEdits` without | `approval_policy=never` |
| Its own sandbox | None in this mode | Off (`danger-full-access`) by default |
| Isolation level | `worktree` or `container`, per office, repository or run | The same |
| Budgets | `--max-turns`, `--max-minutes`; `--max-budget-usd` with API billing | `--max-minutes` only |
| Capacity windows | Reported in the stream | Not available in `exec` |

A crash in the middle of a harness run is recovered by resuming the same session: the next worker starts `claude --resume <session>` (or `codex exec resume`) with a note that the previous process was stopped, in the same worktree. A session is started at most five times (the first start plus four resumes); if it has not finished by then, the run fails.

Each run on a repository gets its own git worktree and a `shiioo/<run>` branch, created from the repository's current `HEAD`. Parallel runs never touch each other's files; the branch stays for you to review, merge or delete.

## Rules and approvals

Before every tool call, the harness runs `shiioo hook pre-tool-use` (inside a container, a `curl` call to the same office), a hook both Claude Code and Codex support. The hook posts the planned call to the office. The office judges it against `rules.toml`: `allow` and `deny` answer at once, with the rule's reason; `ask` records an approval request, sends it to your phone, and holds the hook's request open until you answer or six hours pass. The hook then prints the decision and the harness proceeds or refuses the call, telling the model why.

The hook fails closed. If the office is unreachable, the hook denies. A dead server never means an unguarded agent.

On the phone an `ask` is a message with the command and two buttons:

```text
🔐 2fc85b3f wants to run
Bash: git push origin shiioo/2fc85b3f
[ ✅ Allow ]  [ ⛔ Deny ]
```

In the dashboard it is a card on the run's page with the same two buttons. The decision, by whom and when, is an event in the run's log; an unanswered request expires as `deny by timeout`.

## Isolation and secrets

Where a run executes is a setting of the office, of a repository or of one run, and every run records it as its first step after the lease (`isolation: container (shiioo-0fd1bd4e, egress allowlist)`).

- **`worktree`**, the default: the harness runs as your user in the run's worktree, with your files and network. The rules and your approvals are the whole defence.
- **`container`**: the harness runs in a Docker (or Podman) container per run, through the engine you already have. Read-only root filesystem, no capabilities, `no-new-privileges`, a pid limit, optional CPU and memory limits. Only the run's worktree and the repository's `.git` are mounted, at their host paths, so the worktree's `.git` pointer resolves and commits land on the run's branch exactly as at `worktree`. A home directory per run under `.shiioo/sandboxes/` is kept, so a crashed run resumes the same Claude Code or Codex session inside a fresh container. The image is built on first use from a Dockerfile embedded in the binary: Node, git, the GitHub CLI, the build tools, Claude Code and Codex. Codex logs in with your `auth.json` mounted read-only; Claude Code needs a token from `claude setup-token`, stored as the secret `claude-code-oauth-token`, because its keychain login cannot cross into a container.
- **Egress** for container runs is an allow list, enforced at the network layer rather than by asking nicely: the container joins an internal network with no route out, and a small proxy per run on that network and the default bridge forwards TLS tunnels (port 443) and plain HTTP only to the host patterns you allow. The default list is the model providers, GitHub and the package registries of the common toolchains. A program that ignores `HTTPS_PROXY` cannot connect at all. The office's own host is always allowed, so the permission hook works from inside; it is a `curl` call there, because the `shiioo` binary is not in the container.
- **`openshell`**: an adapter over NVIDIA OpenShell's CLI that creates a sandbox with a network policy generated from the same egress rules, uploads the worktree, runs the harness with `sandbox exec` and deletes the sandbox afterwards. Experimental: written against the documentation, not yet run against a gateway.

Secrets are named, not pasted. `shiioo secret set gh-token` stores a value encrypted in `.shiioo/` (XChaCha20-Poly1305 under a local key, both files mode 0600); `[env] GH_TOKEN = "secret:gh-token"` in `config.toml` hands it to every harness run. The run's spec, and so its log, holds the reference. Before anything is recorded, every string is scanned for the known values, raw, base64 and URL-encoded, and each occurrence becomes `[secret:gh-token]`, followed by an event that names the secret and counts the occurrences; the office's own API token is treated the same way. What this does not do: hide the value from the agent itself, which runs its own tools and can read its environment. Redaction protects the record, the phone and the dashboard.

## Capacity

Subscriptions, not money, are the scarce resource. Every Claude Code run reports its five-hour and seven-day windows (how much is used, when they reset); Shiioo records them as `CapacityObserved` events and keeps the latest per provider. `/capacity` and the dashboard header show them.

`[[employees]]` in `config.toml` lists who takes new tasks, in order, each with limits. When a task arrives from Telegram, the dashboard or the issue intake, the first employee whose windows are under its limits takes it; one with no observation yet counts as available. When everyone is exhausted, the task is refused with the reasons. Codex does not report its windows in headless mode, so it counts as available until that is wired.

Runs can also carry a time budget (`--max-minutes`); Claude Code runs additionally take `--max-turns` and, with API billing, `--max-budget-usd`.

## Intake

Label an issue `shiioo` in one of your configured repositories and, with `[intake] enabled = true`, the office picks it up on its next poll through the `gh` CLI: it starts a run whose task is the issue's title, body and URL plus standing instructions (work on the branch, commit, push, open a pull request that closes the issue), comments on the issue with the run id and branch, and when the run ends comments with the outcome and swaps the label to `shiioo:done` or `shiioo:failed`. Issue text is untrusted input handed to an agent; the rules and your approvals still gate every command it tries.

## The office

The office is one Rust binary with an embedded database (redb), running as one process on your machine. It is the server (the record, the rules and approvals, the capacity tracker, the HTTP API with a resumable event stream, the mobile dashboard, the Telegram bot, the workers) and the node that runs the agents. No Postgres, no containers. Remote nodes that dial out to the server are planned; today the only node is the one inside the process.

Nothing listens publicly. The API binds to loopback and every call needs a bearer token. The dashboard reaches your phone over Tailscale (`tailscale serve --bg 7878`), with a certificate from Tailscale and only your devices on the network. The Telegram bot long-polls Telegram's servers, so it needs no inbound connectivity, and it ignores every account but yours.

Everything the office keeps is in `.shiioo/` inside its directory: the database, the tool journal, one worktree per run, `config.toml`, `rules.toml`, the tokens, the intake state, the logs. Copy the directory and the office moves.

## The API

Everything the phone and the dashboard do goes through one HTTP API on loopback, with the bearer token from `.shiioo/api-token`. Runs are created with `POST /v1/runs` (an `Idempotency-Key` header makes a retried create return the same run), listed, read and cancelled. A run's events stream over Server-Sent Events, where each event's id is its `seq`, so a client that reconnects with `Last-Event-ID` resumes exactly where it stopped. Approvals, capacity and employees have their own routes, which the hook, the buttons and the Telegram bot use. The dashboard is static files served by the same binary; it keeps the token in the browser's local storage and talks to the same routes.

## What you write

Your side of the record is a handful of event kinds the office writes on your behalf: a message from you, a rules verdict, an approval requested and an approval decided, a cancel request. They go through the same append path as everything else, under the run's lease, so a worker never sees a half-written decision, and the log shows your part of the story next to the agent's.

## What it is not

- **Not a managed agent cloud.** No organisations, tenants or billing; one owner, one machine. Others do that well, and Shiioo's kernel could serve it, but it is not the product.
- **Not an agent framework.** You don't write agents in Shiioo; you hire ones that exist.
- **Not a chat app.** Conversations happen, but the unit of work is a task with an outcome on the record.

The design documents go further: [Design](/design/) maps them.
