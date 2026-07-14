# Spriterrific Agent Skills

Agent skills for [Spriterrific](https://www.spriterrific.com) — turn a text
prompt or reference image into game-ready 2D character anchors and animation
spritesheets, generated on Spriterrific's cloud workers.

A *skill* is a markdown playbook (`SKILL.md`) that coding agents like Claude
Code, Cursor, and Codex read to learn a workflow. Install the skill into your
project, give your agent an API key, and prompt it to generate sprites.

## Skills

| Skill | What it does |
| --- | --- |
| [`spriterrific-api`](skills/spriterrific-api/SKILL.md) | Drive the hosted Spriterrific HTTP API: enqueue character/action sprite jobs, poll status, download spritesheets. |

## Quick Start

### 1. Install the skill into your project

From your project root:

```bash
mkdir -p .claude/skills/spriterrific-api && \
curl -fsSL https://raw.githubusercontent.com/chongdashu/spriterrific-skills/main/skills/spriterrific-api/SKILL.md \
  -o .claude/skills/spriterrific-api/SKILL.md
```

Using Cursor or Codex instead of Claude Code? Install to `.cursor/skills/`
or `.codex/skills/` (or `.agents/skills/`) — same file, same path shape.

### 2. Get an API key

Sign in at [app.spriterrific.com](https://app.spriterrific.com), open
**API keys** in the top bar, and create a key. It is shown once — save it to
your project's `.env`:

```bash
SPRITERRIFIC_API_KEY=sk_...
```

### 3. Prompt your agent

```text
Using the spriterrific-api skill, generate a character: a small bunny knight
with a wooden sword and round shield, with walk, idle, and attack animations.
```

The agent enqueues the job, polls until it
finishes, and downloads the spritesheets, GIF previews, and frame manifests
into `spriterrific-runs/` in your project. Every run also gets a web page at
`app.spriterrific.com/jobs/<jobId>` for in-browser preview.

## Links

- Web app: [app.spriterrific.com](https://app.spriterrific.com)
- Website: [spriterrific.com](https://www.spriterrific.com)
- Python CLI/engine: [github.com/chongdashu/spriterrific-public](https://github.com/chongdashu/spriterrific-public)
