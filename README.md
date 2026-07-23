# devbox-install

One script to turn a fresh Linux box into an AI coding server: agents, a proxy
that holds your keys, and the harness that drives them — all wired together,
all surviving a reboot.

I wrote this after setting up the same stack by hand three times and getting it
wrong three different ways. The third time I wrote the script instead.

## What it installs

Always: `git`, `docker`, `node` (24 LTS via NodeSource).

Optional (on by default, flip with `--no-with-X`):

- **codex**, **claude-code**, **opencode** — the agent CLIs
- **claudex** / **glaude** — wrappers that drive a chosen model through Claude
  Code's interface (claudex → gpt-5.6-sol, glaude → glm-5.2; both overridable)
- **CLIProxyAPI** — one process that holds your upstream keys and exposes a
  single OpenAI/Anthropic-compatible endpoint. Agents talk to it; your real
  keys never leave the box.
- **t3** — the web harness. Runs as a systemd user service, bind to your LAN IP,
  drive the agents from a browser on your laptop.
- **hermes** — the always-on agent, in docker compose (the one containerized piece)
- **grok** (x.ai build), **gh**, **zsh**

## The shape of it

```
[laptop browser] ──▶ [devbox: t3 serve  (systemd, always-on)]
                        ├─ spawns codex / claude / opencode  (host CLIs)
                        └─ all point base_url here ─┐
                                                   ▼
                    [CLIProxyAPI] ◀── one key store, round-robin
                          │
                    [hermes  (docker compose)]
```

Agents edit files on the host. Dependency installs, builds, tests — anything
that runs untrusted postinstall scripts — happen inside per-project containers
(see the template the script drops in `~/projects/_template/`). That's the
package-manager-threat bit: the box stays clean, the container is throwaway.

## Quick start

```bash
# minimal: one provider, expose t3 on the LAN
./devbox-setup.sh \
  --provider 'name=zai base=https://api.z.ai/api/paas/v4 key=$GLM_API_KEY models=glm-4.6v,glm-5.2,glm-5v-turbo' \
  --bind-ip 192.168.1.41

# see what it'd do first
./devbox-setup.sh --dry-run --provider '...'

# add a second provider, skip hermes
./devbox-setup.sh \
  --provider 'name=zai base=... key=$GLM models=glm-5.2' \
  --provider 'name=openrouter base=https://openrouter.ai/api/v1 key=$OR models=anthropic/claude-opus-4.6' \
  --no-with-hermes
```

The provider spec is `name= base= key= models=` — repeat `--provider` as many
times as you have upstreams. `key=$VAR` expands the env var at runtime, so you
don't paste secrets into your shell history.

Secrets you don't pass get generated (`openssl rand -hex 32`) and stashed in
`~/.ai-devbox/.secrets.env`, mode 600.

## Flags worth knowing

| Flag | What |
|------|------|
| `--dry-run` | print every action, change nothing |
| `--force-step <name>` | redo one step (e.g. `cliproxy`) ignoring state |
| `--force` | redo everything |
| `--no-with-X` | skip X (X = hermes, t3, codex, claude, opencode, ...) |
| `--with-gh` | install GitHub CLI (off by default; needs sudo) |
| `--skip-verify` | don't fire real LLM calls at the end (on by default — saves tokens) |
| `--bind-ip` | LAN IP to expose t3 on (empty = localhost only) |

Run `./devbox-setup.sh --help` for the full list.

## Idempotent

Every step writes its name to `~/.ai-devbox/.installed`. Re-running the script
skips what's done. Break something halfway? Fix it, re-run, it picks up where
it left off. Want to force a redo? `--force-step cliproxy`.

## Distros

Tested on Debian stable and Ubuntu latest (see `test/run.sh`). Fedora works too
— that's what I run it on. The script detects dnf vs apt vs pacman and picks
the right commands, including the dnf4/dnf5 split that bites on Fedora 41+.

The NodeSource URL, the gh repo, the CLIProxyAPI release — all fetched at
runtime. Nothing pinned to a 2026 version.

## The test

```bash
bash test/run.sh
```

Spins up throwaway `debian:stable` and `ubuntu:latest` containers, runs the real
script (not dry-run) with a dummy provider, and checks that everything landed:
binaries on PATH, configs valid, wrappers executable, idempotency holds. About
five minutes. Cleans up after itself.

It caught seven real bugs while I was writing it — a hardcoded home path, a
bogus npm flag, a missing `mkdir`, a docker-group crash, a password prompt that
hung headless. Worth running before you trust it on a box you care about.

## Not included

Real API calls and OAuth logins. The script wires the plumbing; you still point
it at your own keys (via `--provider key=$VAR`) and do any browser-based logins
(t3 pairing, hermes dashboard OAuth, `cliproxy -codex-login`) yourself.

## Requirements

A fresh-ish Linux box, sudo access, and an internet connection. The script
installs `curl`/`ca-certificates`/`tar` itself if they're missing — minimal
cloud images don't ship them.

## License

MIT.
