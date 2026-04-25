# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

Generated: 2026-04-25 | Project: server-backup

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| When creating a pull request, opening a PR, or preparing changes for review | branch-pr | ~/.claude/skills/branch-pr/SKILL.md |
| When writing Go tests, using teatest, or adding test coverage | go-testing | ~/.claude/skills/go-testing/SKILL.md |
| When creating a GitHub issue, reporting a bug, or requesting a feature | issue-creation | ~/.claude/skills/issue-creation/SKILL.md |
| When user says "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen" | judgment-day | ~/.claude/skills/judgment-day/SKILL.md |
| When user asks to create a new skill, add agent instructions, or document patterns for AI | skill-creator | ~/.claude/skills/skill-creator/SKILL.md |

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### branch-pr
- Every PR MUST link an approved issue with `status:approved` — no exceptions
- Every PR MUST have exactly one `type:*` label
- Branch names MUST match: `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)\/[a-z0-9._-]+$`
- Run `shellcheck` on all modified shell scripts before opening PR
- Open PR using the project template; automated checks must pass before merge
- Never open a PR without a linked approved issue — it will be blocked by CI

### go-testing
- Use table-driven tests with named cases: `tests := []struct{ name, input, expected string; wantErr bool }{...}`
- Use `t.Run(tc.name, ...)` for sub-tests; each case is isolated
- Use `teatest` for Bubbletea TUI component testing
- Golden file tests: write to `testdata/*.golden`, update with `-update` flag
- Prefer `require` over `assert` when failure should stop the test immediately

### issue-creation
- Use templates only (bug report or feature request) — blank issues are disabled
- Every issue gets `status:needs-review` automatically on creation
- A maintainer MUST add `status:approved` before any PR can be opened
- Questions go to Discussions, not issues
- Search for duplicates before creating a new issue

### judgment-day
- Resolve skill registry BEFORE launching judges; inject compact rules into BOTH judge prompts
- Launch TWO judge sub-agents via `delegate` (async, parallel — never sequential)
- Orchestrator NEVER reviews code itself — only launches, reads, and synthesizes
- Fix Agent is a SEPARATE delegation — never reuse a judge as fixer
- After 2 fix iterations, STOP and ask the user before continuing
- Always wait for BOTH judges to complete before synthesizing — never accept partial verdict
- Inject identical `## Project Standards (auto-resolved)` block into ALL sub-agent prompts

### skill-creator
- Skills are SKILL.md files with YAML frontmatter: name, description (with Trigger:), license, metadata
- Include: When to Use, step-by-step instructions, Critical Patterns, Rules sections
- Compact rules section is mandatory — this is what sub-agents receive
- Skills live in ~/.claude/skills/{skill-name}/SKILL.md or project .claude/skills/
- Trigger phrases must be specific enough to avoid false positives

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| .editorconfig | /home/aespinosa/projects/server-backup/.editorconfig | Indent: space/3, LF, UTF-8 |

No AGENTS.md, CLAUDE.md, or .cursorrules found in project root.
