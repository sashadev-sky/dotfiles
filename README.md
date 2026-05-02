# dotfiles

Personal machine configuration managed by [chezmoi](https://www.chezmoi.io/).

## Setup

**1)** **Install `gitleaks` (one-time)**:

- macOS:

  ```shell
  brew install gitleaks
  ```

- Linux: see <https://github.com/gitleaks/gitleaks#installing>

**2**) **Then enable hooks**:

```shell
git config core.hooksPath .githooks
```

## Repo layout

```txt
.
├── .chezmoiignore
├── .chezmoiscripts/                      # hooks that run during `chezmoi apply`
│   ├── run_after_20-merge-claude-mcp.sh  # merges ~/.claude/mcp_servers.json into ~/.claude.json
│   └── run_after_30-merge-codex-mcp.sh   # merges ~/.codex/mcp_servers.toml into ~/.codex/config.toml
├── .githooks/
│   └── pre-commit                        # runs gitleaks secret scan on every commit
├── .github/workflows/
│   ├── secrets.yml                       # runs gitleaks on every push and PR
│   └── verify-mcp.yml                    # runs scripts/verify-mcp.sh on PRs to main
├── .gitignore
├── .gitleaks.toml                        # gitleaks config
├── dot_claude/
│   └── mcp_servers.json.tmpl             # → ~/.claude/mcp_servers.json  (intermediate)
├── dot_codex/
│   └── mcp_servers.toml.tmpl             # → ~/.codex/mcp_servers.toml   (intermediate)
├── dot_config/mcp/
│   └── servers.yaml.tmpl                 # single source of truth for MCP servers
├── dot_cursor/
│   └── private_mcp.json.tmpl             # → ~/.cursor/mcp.json
├── dot_zshenv.tmpl                       # → ~/.zshenv
├── scripts/
│   └── verify-mcp.sh                     # asserts rendered MCP configs exist, parse, and agree
└── README.md
```

Anything under a `dot_*` path is a chezmoi source file: chezmoi renames `dot_foo` → `~/.foo` and expands any `.tmpl` suffix using values from `~/.config/chezmoi/chezmoi.toml` when running `chezmoi apply`.

## MCP configuration (Cursor, Claude Code, Codex)

A single canonical source drives MCP server configuration for all three AI coding tools.

### Source of truth

`dot_config/mcp/servers.yaml.tmpl` defines every MCP server. Edit this file
to add, remove, or modify a server; everything else is generated.

```yaml
servers:
  - name: <server-name>
    transport: stdio | http
    # stdio:
    command: <executable>
    args: [<arg>, ...]
    env: { KEY: VALUE, ... }
    # http:
    url: <https://...>
    headers: { HEADER: VALUE, ... }
```

## How it flows to each tool

| Tool        | Config file                                 | How it's updated                                                                                                                                      |
| ----------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cursor      | `~/.cursor/mcp.json`                        | Fully generated from `dot_cursor/private_mcp.json.tmpl`.                                                                                              |
| Claude Code | `~/.claude.json` (`mcpServers` key)         | Generated intermediate at `~/.claude/mcp_servers.json`, then merged in by `.chezmoiscripts/run_after_20-merge-claude-mcp.sh`.                         |
| Codex       | `~/.codex/config.toml` (`[mcp_servers.*]`)  | Generated intermediate at `~/.codex/mcp_servers.toml`, then merged in by `.chezmoiscripts/run_after_30-merge-codex-mcp.sh`.                           |

Claude and Codex both write dynamic state (OAuth tokens, per-project trust, session history) into their main config files, so those files cannot be overwritten wholesale. The merge hooks replace only the MCP subsection and leave everything else byte-identical.

## Common tasks

### Add a server

Edit `dot_config/mcp/servers.yaml.tmpl`, then:

```shell
chezmoi apply
```

### Remove a server

Delete the entry from `dot_config/mcp/servers.yaml.tmpl`, then:

```shell
chezmoi apply
```

### Rotate a secret

1. Update `~/.config/chezmoi/chezmoi.toml` with the new value. This file is local only and is never committed.
2. Re-render everything:

    ```shell
    chezmoi apply
    ```

### Bootstrap on a new machine

1. Clone and apply:

    ```shell
    chezmoi init --apply git@github.com:<user>/dotfiles.git
    ```

2. Populate `~/.config/chezmoi/chezmoi.toml` with local secrets (e.g. `context7_api_key`).
3. Apply again:

    ```shell
    chezmoi apply
    ```

## Secrets

Secrets referenced in templates, such as `{{ .context7_api_key }}`, live in `~/.config/chezmoi/chezmoi.toml`, which is machine-local and not part of this repo. Two guards protect against accidental commits of literal secret values:

1. `.gitignore` keeps backup and rendered artifacts out of the repo.
2. `scripts/verify-mcp.sh` greps the tracked tree for exposed key prefixes and fails if it finds one.
