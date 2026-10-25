+++
title = "Design"
description = "The principles, what is built and what is planned, and a map of the documentation: the design documents, the twelve architecture decisions, and where each part lives in the code."
[extra]
eyebrow = "Reference"
toc = true
+++

## Principles

- **The event log is the only state.** Every run is an append-only, hash-chained log; workers hold nothing they cannot rebuild from it. Dashboards, status lines and recovery are reads of the same log. A feature that needs state expresses it as events.
- **Write before acting.** Model responses and tool intents are recorded before their effects, so a crash at any point leaves a log that says what did and didn't happen. Side effects are never retried blindly.
- **Harnesses first.** Claude Code and Codex, run headless on their subscriptions, are the employees. Shiioo's own agent loop exists for local models, not as a replacement for the harnesses.
- **The owner is on a phone.** Every decision an agent cannot make alone becomes a message with two buttons. The rules decide the rest, and every decision is on the record.
- **One binary, one machine, no services to run.** An embedded store, a loopback API, Tailscale for reach. Remote nodes dial out to the server; they never require the server to reach them.
- **A personal workforce, not a managed cloud.** One owner, one office. No tenants, organisations or billing.

## Topology

Today the office is one process: the server and the only node are the same binary on the same machine, with redb underneath.

| | Today | Decided, not built |
|---|---|---|
| Server | One process; redb; loopback API; Tailscale for the phone | Unchanged |
| Nodes | The office's own, plus any machine running `shiioo node`: it enrolls, dials out, takes runs addressed to it and works against the office's log over HTTP ([ADR-0012](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0012-nodes-are-workers-over-the-offices-api.md)) | A login service for nodes; deliverables from nodes |
| Store | redb | A Postgres backend exists and passes the same conformance suite; a cluster no longer requires it (ADR-0003's cluster part is superseded by ADR-0010) |
| Isolation | `worktree` (the owner's user, gated by the rules) or `container` (Docker per run, read-only root, egress allow list), chosen per office, repository or run | `openshell` sandboxes (experimental adapter exists), workspace snapshots |
| Policy | `rules.toml`: first match wins, default ask | Cedar policies and Biscuit credentials |
| The company | Roles, routines on a schedule, the morning report, the chief of staff behind `/plan` with approval into issues | Re-planning on strategy changes, a committed roadmap |

## What exists

The office runs end to end today: the kernel with leases, fencing and recovery; the redb store with a conformance suite shared with an in-memory backend and a Postgres backend; the worker loop with the Claude Code and Codex drivers and the native loop for Anthropic and OpenAI-compatible providers; the rules with the hook that gates every harness command; the HTTP API with a resumable event stream, approvals, capacity and employees; the mobile dashboard; the Telegram bot; the GitHub issue intake; the launchd service with keep-awake; the simulator. Every section of the design documents is marked *(built)*, *(planned)* or *(deferred, ADR-n)*.

<figure class="figure diagram">
<!-- diagram:roadmap -->
<figcaption>Seven phases: six built, the seventh a requirements draft.</figcaption>
</figure>

Planned, and not yet started:

| Area | State |
|---|---|
| `openshell` isolation, workspace snapshots | The `container` level, egress allow lists and the encrypted secret store with redaction are built ([ADR-0011](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0011-containers-through-the-owners-engine.md)). `openshell` is an experimental adapter not yet run against a gateway; snapshots are designed, not built. |
| A node login service, deliverables from nodes, mail reading | Nodes, deliverables and outgoing mail are built ([ADR-0012](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0012-nodes-are-workers-over-the-offices-api.md)); these follow. |
| (superseded) Remote nodes over WebSocket | Replaced by nodes as workers over the office's HTTP API ([ADR-0006](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0006-daemon-dials-out-over-websocket.md), [ADR-0010](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0010-single-binary-server-and-nodes.md)), not built. The only node is the one inside the process. |
| [0011](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0011-containers-through-the-owners-engine.md) | Agents run in containers through the owner's Docker or Podman; egress through a proxy sidecar; secrets sealed locally and redacted from the record. |
| Cedar policies and Biscuit credentials | Decided ([ADR-0005](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0005-cedar-policies-and-biscuit-credentials.md)), not built. Today's rules are the TOML file. |
| ACP (Agent Client Protocol) as a third harness interface | Planned. |
| Fork, rewind, replay and evals over recorded runs | Designed, not built. |
| A committed `ROADMAP.md`, re-planning when strategy documents change, dependencies between plan items | Planned. Today the chief of staff proposes a plan per goal and approval creates independent issues. |
| Codex capacity windows, approvals that survive a server restart, cancellation mid-command | Known gaps, in the [backlog](https://github.com/raskell-io/shiioo/blob/main/docs/backlog.md). |

## Documents

Everything lives in the repository under `docs/`. Where a document and the code disagree, the code wins and the document is wrong.

| Document | Covers |
|---|---|
| [What Shiioo is](https://github.com/raskell-io/shiioo/blob/main/docs/positioning.md) | The product definition, principles, topology and roadmap. Read this first. |
| [Architecture](https://github.com/raskell-io/shiioo/blob/main/docs/architecture.md) | The one rule, the guarantees, components, storage, the crate map. |
| [Glossary](https://github.com/raskell-io/shiioo/blob/main/docs/glossary.md) | Platform terms, and how the virtual-company vocabulary (office, employee, task) maps onto them. |
| [Contributing](https://github.com/raskell-io/shiioo/blob/main/docs/contributing.md) | Building, testing, conventions, how to add an event, a backend, a harness, a rule, a command, a route. |
| [Backlog](https://github.com/raskell-io/shiioo/blob/main/docs/backlog.md) | Known rough edges, to fix or consciously keep. |
| [Porting from shiioo-legacy](https://github.com/raskell-io/shiioo/blob/main/docs/legacy-port.md) | What was kept, replaced or dropped from the previous codebase. |

### Design documents

| Document | Covers |
|---|---|
| [Event log](https://github.com/raskell-io/shiioo/blob/main/docs/design/event-log.md) | Event format, hashing over stored bytes, the payload catalogue, external input, blobs, schema evolution, backends, archival, streaming. |
| [Execution](https://github.com/raskell-io/shiioo/blob/main/docs/design/execution.md) | Run lifecycle, scheduling, the worker loop, leases, cancellation, subagents, recovery, failure modes, simulation. |
| [Tools and machines](https://github.com/raskell-io/shiioo/blob/main/docs/design/tools-and-machines.md) | Tool model, built-in and MCP tools, nodes and their protocol, isolation levels, worktrees and snapshots, secrets. |
| [Runtimes and providers](https://github.com/raskell-io/shiioo/blob/main/docs/design/runtimes-and-providers.md) | The native loop, the Claude Code and Codex drivers, ACP (planned), model providers and the router, context building. |
| [Governance](https://github.com/raskell-io/shiioo/blob/main/docs/design/governance.md) | The owner's rules, approvals, budgets, change management, the virtual-company template. |
| [Fork and replay](https://github.com/raskell-io/shiioo/blob/main/docs/design/fork-and-replay.md) | Rewind, fork, diff, replay and evals. |
| [API](https://github.com/raskell-io/shiioo/blob/main/docs/design/api.md) | REST and SSE, employees, permissions and approvals, capacity, diff, the dashboard, errors, auth. |
| [Telegram](https://github.com/raskell-io/shiioo/blob/main/docs/design/telegram.md) | Commands, approvals with one tap, notifications, security of the bot. |
| [Intake](https://github.com/raskell-io/shiioo/blob/main/docs/design/intake.md) | Work arriving as labelled GitHub issues: the label protocol, the task prompt, dedup and state, failure handling. |
| [Security](https://github.com/raskell-io/shiioo/blob/main/docs/design/security.md) | Threat model, controls, today's posture, and what is not protected. |
| [Deployment](https://github.com/raskell-io/shiioo/blob/main/docs/design/deployment.md) | The office on one Mac (install, keep-awake, Tailscale), several machines, config, observability, upgrades, backups. |

## Decisions

Each architecture decision record holds one decision: the context, what was chosen, what was given up, and when to revisit. Records are never edited after acceptance except for their status; a changed decision gets a new record that supersedes the old one. The [index](https://github.com/raskell-io/shiioo/blob/main/docs/adr/README.md) has the template.

| # | Decision |
|---|---|
| [0001](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0001-event-log-is-the-only-state.md) | The per-run event log is the only state. |
| [0002](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0002-leases-with-fencing.md) | Run ownership through leases with fencing tokens. |
| [0003](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0003-redb-default-postgres-for-clusters.md) | redb by default, Postgres for clusters. The cluster part is superseded by 0010. |
| [0004](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0004-rest-and-sse-api.md) | REST plus resumable SSE as the only public API. |
| [0005](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0005-cedar-policies-and-biscuit-credentials.md) | Cedar for policies, Biscuit for agent credentials. |
| [0006](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0006-daemon-dials-out-over-websocket.md) | Machines run a daemon that dials out over WebSocket. |
| [0007](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0007-rewrite-under-apache-2.md) | Rewrite Shiioo from scratch under Apache-2.0. |
| [0008](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0008-personal-workforce-not-managed-cloud.md) | The product is a personal agent workforce, not a managed agent cloud. |
| [0009](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0009-harness-first-runtimes.md) | Harnesses are the primary runtime; the native loop serves local models. |
| [0010](https://github.com/raskell-io/shiioo/blob/main/docs/adr/0010-single-binary-server-and-nodes.md) | One binary: a server, nodes that dial out, an embedded store. |

## Where to look in the code

A Cargo workspace of ten crates, one binary. Each crate has a README (purpose, API, how to test) and a `docs/` directory for maintainers.

| Crate | Owns | Read |
|---|---|---|
| `shiioo-core` | The event format, hashing, leases and epochs, the recovery rules. No I/O. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-core/README.md), [invariants](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-core/docs/invariants.md), [recovery](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-core/docs/recovery.md) |
| `shiioo-store` | The `EventStore` trait and its backends: redb, memory, Postgres. Every backend passes one conformance suite. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-store/README.md), [backends](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-store/docs/backends.md), [conformance](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-store/docs/conformance.md) |
| `shiioo-runtime` | The worker loop, the Claude Code and Codex drivers, tools, the machine and its journal, worktrees. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-runtime/README.md), [worker loop](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-runtime/docs/worker-loop.md), [harness adapters](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-runtime/docs/harness-adapters.md), [machine and tools](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-runtime/docs/machine-and-tools.md) |
| `shiioo-rules` | What agents may do without asking: the TOML format, matching, the defaults. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-rules/README.md), [rules format](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-rules/docs/rules-format.md) |
| `shiioo-providers` | OpenAI-compatible model providers for the native loop (Ollama, LM Studio, MLX). | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-providers/README.md), [OpenAI-compatible](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-providers/docs/openai-compat.md) |
| `shiioo-api` | HTTP routes, the event stream, approvals, capacity, employees, the dashboard. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-api/README.md), [HTTP](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-api/docs/http.md), [approvals and capacity](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-api/docs/approvals-and-capacity.md), [dashboard](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-api/docs/dashboard.md) |
| `shiioo-telegram` | The bot: commands, the owner gate, approval buttons, notifications. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-telegram/README.md), [protocol](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-telegram/docs/protocol.md) |
| `shiioo-intake` | Labelled GitHub issues becoming runs, through the `gh` CLI. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-intake/README.md), [flow](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-intake/docs/flow.md) |
| `shiioo-sim` | The seeded simulator: crashes, lease races, machine restarts over thousands of scenarios. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-sim/README.md), [scenarios](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo-sim/docs/scenarios.md) |
| `shiioo` | The binary: CLI commands, the config file, the service installer, the hook program, the office that ties the crates together. | [README](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo/README.md), [office layout](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo/docs/office-layout.md), [service](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo/docs/service.md), [hook](https://github.com/raskell-io/shiioo/blob/main/crates/shiioo/docs/hook.md) |

## Working on it

```sh
cargo build --workspace
cargo test                                             # unit, integration and simulation tests; no services needed
cargo clippy --workspace --all-targets --all-features  # must be clean
python3 scripts/check-docs.py                          # every relative link in the docs must resolve
```

The workspace forbids `unsafe` and denies `unwrap()`. Tests never run the real `claude` or `codex`; they drive fakes that replay recorded output, and the recordings are real, sanitised output from the real tools. Docs carry status markers, and decisions worth not re-litigating get a record. There is no release process yet: `cargo install --path crates/shiioo` on the office machine, then `shiioo uninstall && shiioo install` to pick up a new binary. The rest is in [Contributing](https://github.com/raskell-io/shiioo/blob/main/docs/contributing.md).

Shiioo is Apache-2.0, at [github.com/raskell-io/shiioo](https://github.com/raskell-io/shiioo). The previous codebase is [shiioo-legacy](https://github.com/raskell-io/shiioo-legacy).
