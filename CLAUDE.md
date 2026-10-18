# CLAUDE.md

Claude Code guidance for this repository. The canonical agent instructions live in AGENTS.md.

@AGENTS.md

## Plugin Setup

```bash
claude plugin install elixir@claude-code-elixir
claude plugin install superpowers@claude-plugins-official
claude plugin install code-review@claude-plugins-official
```

## Claude-specific notes

- This is an Elixir library, not a Phoenix app. Skip the Phoenix/Ecto/LiveView guidance from the scaffold skills; the `elixir-scaffold` skill (Mix Library flavour) is only useful as a style reference.
- There is no `mix precommit`. Use the quality gate listed under "Essential Commands" in AGENTS.md before declaring work done (`superpowers:verification-before-completion`).
- Use `superpowers:test-driven-development` for backend changes and `code-review` before opening a PR.
- `/Users/manu/Projects/hammer` is the upstream Hammer core and is a read-only reference.
- Do not tag, publish to Hex, or commit unless explicitly asked.
