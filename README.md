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

Pick whichever suits you:

**Option A — download the zip.** Grab
[`spriterrific-api-skill.zip`](https://github.com/chongdashu/spriterrific-skills/releases/latest/download/spriterrific-api-skill.zip)
from the latest release and unzip it at your project root. It installs the
skill under both `.claude/skills/` and `.agents/skills/`:

```bash
curl -fsSL -o spriterrific-api-skill.zip \
  https://github.com/chongdashu/spriterrific-skills/releases/latest/download/spriterrific-api-skill.zip
unzip -o spriterrific-api-skill.zip && rm spriterrific-api-skill.zip
```

**Option B — let your agent do it.** Paste this to your coding agent:

```text
Install the Spriterrific API agent skill into this project.

1. Fetch https://raw.githubusercontent.com/chongdashu/spriterrific-skills/main/skills/spriterrific-api/SKILL.md
2. Save it to .claude/skills/spriterrific-api/SKILL.md and
   .agents/skills/spriterrific-api/SKILL.md, creating directories as needed.
   If this project keeps agent skills elsewhere (e.g. .cursor/skills/ or
   .codex/skills/), install it there too.
3. Confirm the files exist, then read the skill and summarize what it can do
   and what it needs from me.
```

**Option C — manual.** From your project root:

```bash
mkdir -p .claude/skills/spriterrific-api && \
curl -fsSL https://raw.githubusercontent.com/chongdashu/spriterrific-skills/main/skills/spriterrific-api/SKILL.md \
  -o .claude/skills/spriterrific-api/SKILL.md
```

Repeat with `.agents/skills/` (or `.cursor/skills/`, `.codex/skills/`) if
your agent reads skills from a different directory.

### 2. Get an API key

Sign in at [app.spriterrific.com](https://app.spriterrific.com), open
**API keys** in the top bar, and create a key. It is shown once — save it to
your project's `.env`:

```bash
SPRITERRIFIC_API_KEY=sk_...
```

### 3. Prompt your agent

```text
Using the spriterrific-api skill, generate a character: a chubby orange tabby
cat in a red hoodie, with walk and idle animations.
```

The agent enqueues the job, polls until it
finishes, and downloads the spritesheets, GIF previews, and frame manifests
into `spriterrific-runs/` in your project. Every run also gets a web page at
`app.spriterrific.com/jobs/<jobId>` for in-browser preview.

## Links

- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Web app: [app.spriterrific.com](https://app.spriterrific.com)
- Website: [spriterrific.com](https://www.spriterrific.com)
- Python CLI/engine: [github.com/chongdashu/spriterrific-public](https://github.com/chongdashu/spriterrific-public)
