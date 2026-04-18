# dotfiles

Personal machine configuration managed by [chezmoi](https://www.chezmoi.io/).

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
