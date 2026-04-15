---
name: Custom Perl LSP plugin for Claude Code
description: perl-navigator-lsp custom plugin registered at ~/.claude/plugins/perl-navigator-lsp — uses PerlNavigator over stdio for .pm/.pl/.t/.psgi files
type: project
---

A custom Claude Code LSP plugin was created for Perl language intelligence using PerlNavigator.

**Location**: `~/.claude/plugins/perl-navigator-lsp/`
- `.claude-plugin/plugin.json` — plugin manifest (name, version, lspServers pointer)
- `.lsp.json` — LSP server config (command: `perlnavigator --stdio`, handles `.pm`, `.pl`, `.t`, `.psgi`)

**Binary**: `perlnavigator` installed via mise/node at `~/.local/share/mise/installs/node/24.14.0/perlnavigator`

**Registration** (added 2026-04-14):
- `installed_plugins.json`: registered as `perl-navigator-lsp@local`
- `settings.json`: enabled as `perl-navigator-lsp@local: true`

**Why:** Official Claude Code LSP plugins don't include Perl support. This plugin provides go-to-definition, hover, references, and diagnostics for the large DreamHost Perl codebase in `dh/ndn/perl/`.

**How to apply:** If the plugin isn't loading (LSP returns "No LSP server available for .pm"), check that the registration entries still exist in both `installed_plugins.json` and `settings.json`. Can also test with `claude --plugin-dir ~/.claude/plugins/perl-navigator-lsp`. Requires a session restart to pick up config changes.
