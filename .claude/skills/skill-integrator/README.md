# skill-integrator

A meta-skill for Claude Code that integrates other skills into your project's existing file structure — preventing duplicate files, parallel configurations, and orphan artifacts.

## Problem

Claude skills are written without knowledge of your specific project. They create "default" files (`.claude/settings.json`, `README.md`, `notes.md`, `decisions.md`) even when your project already has those concepts under different names or paths. Result: two files for one purpose, drift, regressions.

## Solution

`skill-integrator` is a gatekeeper that:

1. **Routes** — before another skill writes files, redirects its outputs to your existing project files.
2. **Adapts** — when you add a new skill, edits its paths to match your project, or adds redirect rules.
3. **Logs** — keeps an append-only record of every integration decision so future sessions don't re-discover them.

## Install

1. Copy `.claude/skills/skill-integrator/` into your project.
2. Copy `integration-map.md.example` → `integration-map.md` and fill in your project's paths.
3. Reference the skill in your project's `CLAUDE.md` (or `AGENTS.md`):
   > Before running any skill that writes files, first invoke `/skill-integrator` or read `.claude/skills/skill-integrator/integration-map.md`.

## Three modes

- **Mode A — Run another skill safely.** "Run `/X` via skill-integrator." It reads the map, runs `/X`, redirects outputs.
- **Mode B — Add a new skill.** "Integrate this new skill from `<url>`." It rewrites the new skill's paths to match your project.
- **Mode C — Audit.** "Audit installed skills." Reports conflicts and orphan paths.

## Files

| File | Purpose | Marketplace? |
|---|---|---|
| `SKILL.md` | Universal framework | ✅ ships |
| `integration-map.md.example` | Empty template | ✅ ships |
| `integration-map.md` | Your project's data | ❌ stays in your repo |
| `README.md` | This file | ✅ ships |

## Hard invariants (always enforced)

1. **One file = one purpose.**
2. **Extend, don't proliferate.** New category → ask user → add map entry → only then create file.
3. **Map is the authority.** Skill defaults lose to map entries.
4. **Precedent log is append-only.**
5. **Skill and map commit together.**

## License

MIT (or whatever you prefer when publishing).

## Version

1.0.0
