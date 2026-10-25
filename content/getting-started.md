+++
title = "Getting started"
description = "Set up the office on a Mac that stays on, connect your phone, and hand your first task to Claude Code or Codex. About half an hour, most of it waiting for a build."
[extra]
eyebrow = "Guide"
toc = true
next = { title = "How it works", url = "/how-it-works/" }
+++

## What you need

- **A Mac that stays on.** The office is one process on one machine; `shiioo install` keeps that machine awake while it runs. A Mac Studio or Mac mini in a cupboard is the intended shape. Linux works for the server part, but the service installer there is untested.
- **Claude Code and/or Codex, logged in.** Run `claude` and `codex` once on that Mac and sign in with your subscriptions. Shiioo drives them headless and strips any `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` from their environment, so runs bill your subscriptions, not API credits.
- **A Telegram bot and your user id.** Create a bot with [@BotFather](https://t.me/BotFather); it gives you a token. Message `@userinfobot` to learn your own numeric id. The bot answers nobody else.
- **Tailscale on the Mac and on your phone**, same account. That is how the dashboard reaches your phone without a public address.
- **Repositories on disk.** The agents work in git worktrees of repositories you have cloned on the Mac.
- **Rust** (`cargo`), to build the binary. There are no releases yet.

## Install

```sh
git clone https://github.com/raskell-io/shiioo.git
cd shiioo
cargo install --path crates/shiioo        # one binary: shiioo
```

Pick a directory for the office. Everything Shiioo keeps lives in `.shiioo/` inside it.

```sh
export SHIIOO_TELEGRAM_TOKEN=...                 # from @BotFather
shiioo --workspace ~/shiioo-office install
```

`install` writes a launchd agent (`~/Library/LaunchAgents/io.raskell.shiioo.plist`) that starts the office at login, restarts it if it stops, runs it with your current `PATH` so it finds `claude`, `codex`, `gh` and `git`, and passes `--keep-awake`, which ties a `caffeinate` to the process. It stores the Telegram token in `.shiioo/telegram-token` with owner-only permissions and prints:

```text
installed ~/Library/LaunchAgents/io.raskell.shiioo.plist and started it
logs: ~/shiioo-office/.shiioo/logs/serve.log
dashboard on this machine: http://127.0.0.1:7878/#token=<token>
from your phone, once: tailscale serve --bg 7878
then open: https://<mac>.<tailnet>.ts.net/#token=<token>
```

The last two lines appear when Tailscale is installed and up. `shiioo install --print` shows the service definition without installing it; `shiioo uninstall` removes it and leaves `.shiioo/` alone. To run the office in the foreground instead, `shiioo --workspace ~/shiioo-office up`.

## Configure

The first start writes `~/shiioo-office/.shiioo/config.toml` with every section commented. Fill in your id and your repositories:

```toml
[telegram]
owner_chat_id = 123456789            # your Telegram user id; the bot obeys nobody else

[dashboard]
url = "https://mac-studio.tail1234.ts.net"   # where your phone reaches the dashboard; notifications link here

[repos]
shiioo = "/Users/me/code/shiioo"     # label = absolute path of a clone
site = "/Users/me/code/site"

[intake]
enabled = false                      # true: work on GitHub issues labelled `shiioo` in the repos above (needs `gh` logged in)
label = "shiioo"
interval_secs = 60

# Who takes new tasks, in order. An employee is skipped once its subscription
# window is above the limit. Without this section: claude, then codex.
[[employees]]
name = "claude"
kind = "claude-code"
max_five_hour = 0.95
max_seven_day = 0.90

[[employees]]
name = "codex"
kind = "codex"

# [[employees]]
# name = "local"
# kind = "native"
# model = "ollama/qwen3:32b"           # Shiioo's own loop against a local model
```

Restart the service after editing (`launchctl kickstart -k gui/$(id -u)/io.raskell.shiioo`). The token can also come from `SHIIOO_TELEGRAM_TOKEN` or `[telegram] token`; with a token but no `owner_chat_id` the bot stays off and the log says so.

## The rules

`.shiioo/rules.toml` says what agents may do without asking you. It is written with defaults on first start, and every tool call a harness wants to make is judged against it before it runs: `allow` lets it through, `deny` refuses it with a reason the agent sees, `ask` sends it to your phone.

```toml
default = "ask"

[[rules]]
tool = ["Bash", "shell"]
command = "git push --force*"
decision = "deny"
reason = "rewrites shared history"

[[rules]]
tool = "Bash"
command = "git push *"
decision = "ask"
reason = "pushes leave the machine"

[[rules]]
tool = ["Read", "Glob", "Grep", "WebFetch"]
decision = "allow"
```

How to read it:

- Rules are tried in file order; the first one whose conditions all hold decides. Nothing matches: `default` decides, and the default is `ask`.
- `tool` is the harness's tool name (`Bash`, `Read`, `Edit`, `Write`, …), `command` a glob on a shell command, `path` a glob on a file path, `repo` a glob on the repository label from `[repos]`. Globs: `*` any run of characters, `?` one character, anchored at both ends. These are Shiioo's globs on Shiioo's fields; they are not Claude Code's own `--allowedTools` syntax (`Bash(git *)`), which Shiioo does not use when the hook is active.
- A chained command (`a && b | c`) is judged as a whole and segment by segment; the most restrictive verdict wins. `git status && git push origin x` asks because of the push.
- The defaults deny `sudo`, `rm -rf /*`, force pushes and piping downloads into a shell; ask for `git push`, `git rebase`, `gh`, `rm`, `docker`, `brew`, package installs and publishes; allow the everyday read, edit, git, cargo, npm and shell inspection commands. Keep denies above asks above allows when you edit.

Expect a few `ask`s in the first days for harmless tools that aren't in the list (Claude Code likes `od -c`, for example). Every ask is in the run's log; add the ones you trust.

## The phone

Open the dashboard link `install` printed on your phone once, with the `#token=…` fragment; the page stores the token locally and drops it from the address. Add it to the home screen. Then, in Telegram, send `/start` to your bot.

| You send | What happens |
|---|---|
| `fix the flaky test in tests/net.rs and commit` | Starts a run with that task. One repo configured: it is used. Several: the bot asks you to name one with `/run`. |
| `/run shiioo fix the flaky test …` | Same, on the repo labelled `shiioo`. |
| `/status` | The 15 most recent runs, one line each, then the capacity line. |
| `/log <run>` | The run's last 25 steps. `<run>` may be the first four or more characters of its id. |
| `/cancel <run>` | Stops the run at its next step. |
| `/capacity` | How much of each subscription's five-hour and seven-day window is used, and when it resets. |
| `/repos` | The labels you can name in `/run`. |
| `/approve <id>`, `/deny <id>` | Answer a request without the buttons. |
| `/help` | The list. |

## The first task

Send `/run shiioo add a line "Hello from Shiioo" to README.md and commit it`. The bot replies with the run id, the employee that took it and the branch (`shiioo/<8 characters>`). The agent works in its own worktree of the repository, on that branch.

If a command needs you, a message arrives:

```text
🔐 2fc85b3f wants to run
Bash: date
https://mac-studio.tail1234.ts.net/#run=2fc85b3f-…
[ ✅ Allow ]  [ ⛔ Deny ]
```

Tap. The harness, which has been waiting on the answer, continues. When the run ends:

```text
✅ 2fc85b3f finished: add a line "Hello from Shiioo" to README.md and commit it

Appended the line to README.md and committed it as f331eb4 — "docs: hello". Nothing was pushed.
```

A failed run says `❌` and why; one that needs you says `⚠️`. The dashboard shows the same run with its live log, a Diff button for the branch against your `main`, Cancel, and the Allow / Deny card while a request is open. Pushing and opening a pull request are commands like any other: with the default rules they ask you first.

## From a terminal

The same runs work without the office, straight from a terminal on the Mac:

```sh
shiioo --workspace ~/shiioo-office run --harness claude-code --repo ~/code/shiioo "Fix the flaky test and commit"
shiioo --workspace ~/shiioo-office log <run-id>        # every step, hash chain verified
shiioo --workspace ~/shiioo-office resume <run-id>     # after Ctrl-C or kill -9: the same Claude Code session continues
```

`--harness codex` uses Codex. Without `--harness`, Shiioo's own loop runs the task with the model named by `--model`: `claude-opus-5-5` needs `ANTHROPIC_API_KEY`; `ollama/<model>` uses a local Ollama. Terminal runs don't go through the rules (there is no server for the hook to ask); the harness's own permission mode applies, `acceptEdits` by default. The office and a terminal run cannot use the same `.shiioo/` at the same time: the embedded database allows one process.

## What the office keeps

| Path under `.shiioo/` | Contents |
|---|---|
| `shiioo.redb` | The event log: every run, every step. The only state. Back this up and you have backed up the office. |
| `journal.jsonl` | The local machine's tool-call journal, used to recover after a crash. |
| `worktrees/<run>/` | One git worktree per repository run, branch `shiioo/<8 characters>`. Branches stay in your repository after the run. |
| `config.toml`, `rules.toml` | Above. |
| `api-token`, `telegram-token` | Bearer token for the API and dashboard; the bot token. Mode 0600. |
| `sandboxes/<run>/` | For `container` runs: the run's home directory (kept for resumes), its egress proxy configuration. |
| `secrets.key`, `secrets.enc` | The encrypted secret store (`shiioo secret`). Mode 0600. |
| `intake-state.json` | Which GitHub issues were already picked up. |
| `logs/serve.log` | The service's output. |

## Keeping it running

```sh
launchctl print gui/$(id -u)/io.raskell.shiioo | head      # is it running?
tail -f ~/shiioo-office/.shiioo/logs/serve.log
launchctl kickstart -k gui/$(id -u)/io.raskell.shiioo      # restart (after editing config.toml or replacing the binary)
```

Runs survive restarts: a worker that comes back reads the log and continues, and resumes the same Claude Code or Codex session. To upgrade, build the new binary and restart; if its path changed, `shiioo uninstall` and `install` again.

## Running agents in containers

By default a harness runs as your user, in its worktree, with your network: the `worktree` level. For unattended work, switch the office or a repository to the `container` level. It needs Docker running on the Mac (colima works) and the office and its repositories under your home directory, which is what Docker's VM can see.

```toml
[isolation]
default = "container"           # or per repository: [isolation.repos] myproject = "container"

[isolation.container]
memory = "8g"
cpus = 4.0

[egress]
mode = "allowlist"              # the model APIs, GitHub and the package registries; add with `also = [...]`
```

Each run then gets its own container: a read-only root filesystem, no capabilities, only the run's worktree and the repository's `.git` mounted (at their host paths, so commits land on the run's branch as before), a home directory of its own that survives resumes, and a network whose only way out is a proxy that admits TLS to the hosts on the list. `shiioo sandbox build` builds the image ahead of time (it takes a few minutes; otherwise the first run does it).

Codex logs in with the `auth.json` from your `codex login`, mounted read-only. Claude Code's login lives in the macOS keychain, which a container cannot read, so give it a token once:

```sh
claude setup-token                                   # prints a long-lived token for your subscription
shiioo --workspace ~/shiioo-office secret set claude-code-oauth-token     # paste it on stdin
```

Anything else an agent needs, such as a GitHub token for `gh` and pushes over HTTPS (the container has no SSH keys), goes the same way and is referenced by name:

```sh
echo -n ghp_… | shiioo --workspace ~/shiioo-office secret set gh-token
```

```toml
[env]
GH_TOKEN = "secret:gh-token"
```

The value reaches the harness and nothing else: the run's record holds the reference, and if the agent ever prints the value, the log, the phone and the dashboard show `[secret:gh-token]` instead, with an event saying a secret was redacted. Every run records where it executed (`isolation: container (shiioo-0fd1bd4e, egress allowlist)`).

## Caveats, honestly

- **`worktree` has no OS sandbox.** At the default level a harness runs with your user's permissions; the rules and your approvals are what stand between an agent and your machine. Use the `container` level for anything you would not run as yourself. A container is not a VM: it bounds mistakes and persuasion, not a kernel exploit, and the agent can still read the secrets it was given.
- **`openshell` is experimental.** The adapter follows NVIDIA OpenShell's documentation and has not been run against a gateway yet; it works on an uploaded copy of the worktree, so results come back through git.
- **Sandboxed runs reach the network over TLS on 443 and plain HTTP only.** No SSH, no other ports; GitHub remotes are rewritten to HTTPS inside the container.
- **Codex's own sandbox is off** by default, because headless Codex cannot ask for an exception and its workspace sandbox blocks `git commit`. Codex also ignores `--max-turns` and `--max-budget-usd`; `--max-minutes` is the budget that applies to both harnesses.
- **Approvals don't survive a server restart.** The request is in the log, but the harness that was waiting sees a denial after its own timeout (about six hours).
- **Telegram and local models** have been tested against fakes, not yet against a real bot or a running Ollama.
- **`shiioo install` on Linux** writes a systemd user unit that nobody has exercised yet.
