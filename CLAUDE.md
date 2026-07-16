# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Keep this file up to date**: when a change makes anything documented here inaccurate (commands, config structure, build flow, conventions), update this file in the same change.

## What This Is

"Workspace" — a portable, dockerized DevOps toolbox (github.com/vtvz/workspace). It is cloned as a `.ws` subdirectory into host projects and exposed as a `just` module via `mod? ws '.ws/Justfile'` in the host project's Justfile. This repo is independent of the host project around it — do not treat parent-directory files as part of this project.

Commands are run from the **host project root** as `just ws <command>` (requires just 1.31+ for modules), or standalone from inside this repo as plain `just <command>` — no host project needed. Two things make standalone work: the committed `.ws → .` symlink (so the `.ws/...` paths in recipes resolve to this repo itself) and the `ns` variable (expands to `ws::` when loaded as a module, empty standalone). `install`/`update` remain embedded-only — the install guard rejects running inside this repo.

## Commands

```bash
just ws install          # One-time setup in a host project (symlinks, git excludesFile, tflint config)
just ws build            # Render templates and build the Docker image
just ws shell            # zsh inside the container (alias: just ws sh)
just ws profile <name>   # Wrap shell in aws-vault exec (profile name required)
just ws psh <name>       # profile + shell combined
just ws validate         # hadolint the rendered Dockerfile
just ws update           # git pull this repo, re-install, rebuild
just ws git-cleanup      # Delete local branches whose remote is gone
```

`bin/check-updates` runs **inside the container** (needs env vars baked in at build time). `check-updates check` reports outdated tool versions; `check-updates apply` rewrites versions in `config.yaml`. The upgrade flow it prints — rebuild, then commit `config.yaml` with message `Tools upgrade` — is the convention used throughout this repo's history.

## Architecture

Everything flows from `config.yaml` through gomplate templating:

- `config.yaml` — single source of truth: tool versions (github releases, pip, misc), feature flags (`tools.enabled.*`), shell/user settings, dotenv defaults.
- A host project may place `.ws.config.yaml` in its root to override any config value; gomplate merges it as `config=merge:local|global` (see the `gomplate` recipe in the Justfile). Every template render goes through that recipe, which runs gomplate in its own Docker container.
- `templates/Dockerfile.tmpl` → rendered to `var/Dockerfile` (gitignored). The Dockerfile is multi-stage: `core` base stage, then one `FROM core AS <tool>` stage per tool that downloads its pinned version, assembled at the end. **Adding a tool requires both a version entry in `config.yaml` and a corresponding stage/template edit in `Dockerfile.tmpl`.**
- `templates/.env.tmpl` → rendered to `.ws.env` in the host project root (from the `dotenv:` map in config).

`docker-compose.yml` runs the container with host networking, the host project mounted at `/workspace`, the Docker socket passed through, and AWS credential env vars forwarded (populated by aws-vault via `just ws profile`). Persistent per-tool state (kubeconfig, helm cache, terraform plugin cache, zsh history, 1Password config) lives in `var/*` — gitignored except keeper `.gitignore` files.

Other pieces:

- `tools/` — configs mounted or copied into the container (zsh, starship, direnv, zellij, tflint).
- `project.gitignore` — applied to the **host** repo via `git config core.excludesFile` during install, so workspace artifacts (`.ws/`, `.ws.env`, `Justfile` symlink, etc.) stay out of the host project's git.
- `just ws profile` uses a flock on a per-project lock file so concurrent aws-vault invocations don't race.

## Notes

- The `compose` recipe sets `BUILDX_BUILDER=${BUILDX_BUILDER:-default}` deliberately — the containerized buildx builder stalls on some networks (MTU issues); keep this when touching build recipes.
- Justfile recipes are `[no-cd]`: they execute relative to the invocation directory (the host project root), not this directory. Paths in recipes assume that.