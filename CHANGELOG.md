# Changelog

All notable changes to the Spriterrific agent skills are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Every release is tagged and ships a rebuilt `spriterrific-api-skill.zip`
asset (built by `scripts/package.sh`), which is what
`releases/latest/download/spriterrific-api-skill.zip` — and therefore the
app.spriterrific.com download button — serves.

## [Unreleased]

## [1.2.1] - 2026-07-16

### Changed

- `spriterrific-api`: costs are documented in credits only, inside the
  skill; the README no longer covers pricing at all.

## [1.2.0] - 2026-07-15

### Added

- `spriterrific-api`: custom action names — action jobs can request a
  freeform lowercase slug (e.g. `sliding-tackle`, `kick`) paired with an
  `actionBaselines` entry mapping it to the standard action whose engine
  preset backs it (e.g. `{ "sliding-tackle": "attack" }`). Artifacts and
  step ids carry the custom name, so moves derived from the same baseline
  never collide. New "Custom Actions (baseline + label)" section plus an
  anti-pattern against forcing domain moves into standard action identities.
- `spriterrific-api`: the documented standard action vocabulary expanded
  from 8 to the engine's full 23 presets (adds `talk`, `interact`,
  `pick_up`, `use`, `examine`, `give`, `shrug`, `walk_forward`,
  `walk_backward`, `block_high`, `block_low`, `knockdown`, `get_up`,
  `light_attack`, `heavy_attack`).

### Changed

- `spriterrific-api`: action jobs now inherit `direction` from the
  reference job when omitted (previously defaulted to `w` and failed
  against non-west anchors); pass `direction` only to override.

## [1.1.2] - 2026-07-15

### Changed

- `spriterrific-api`: image pose-board mode retired from the hosted service —
  every action runs in video mode, and `actionModes` values of `"image"` are
  now rejected with a 400. Guidance for idle drift now recommends a tightened
  `actionContext` regenerate instead.

## [1.1.1] - 2026-07-15

### Changed

- `spriterrific-api`: API keys moved to a dedicated **API keys** page in the
  web app's top navigation (no longer under Settings).

## [1.1.0] - 2026-07-15

### Added

- `spriterrific-api`: hosted frame picker — agents can list dense-frame
  thumbnails, create versioned spritesheet picks, and activate a version
  via `/api/v1/jobs/{id}/actions/{action}/frames` and `…/picks` (0 credits;
  Studio Frames tab / CLI `frame-picker` + `process-selection` equivalent).

## [1.0.4] - 2026-07-15

### Changed

- `spriterrific-api`: documented the `engineVersion` / `workerVersion` fields
  on finished jobs — agents should quote `engineVersion` when reporting or
  comparing run quality, since behavior changes ship as engine releases.

## [1.0.3] - 2026-07-15

### Changed

- `spriterrific-api`: updated where API keys live in the redesigned web app
  (Quickstart page or Settings → API keys, instead of the old top-bar menu).

## [1.0.2] - 2026-07-14

### Changed

- `spriterrific-api`: hosted jobs now run **every** action in video mode by
  default (the API fills `actionModes` server-side); the skill documents
  image mode as an explicit opt-in anti-drift tactic rather than a
  per-action engine default.
- `spriterrific-api`: documented the `{ "job": { ... } }` response envelope
  on job GETs — pollers must read `job.status`, not a top-level `status`.
- `spriterrific-api`: added a download note (prefer `curl` for public R2
  artifact URLs; default-User-Agent Python `urllib` can 403) and a
  debugging note (fetch the `costs` / `run-index` artifacts to report which
  model actually ran).
- `spriterrific-api`: warned that video prompts have a 4096-character model
  cap — keep `actionContext` short (~100 chars) or the generation fails
  (refunded) with a prompt-too-long error.

## [1.0.1] - 2026-07-14

### Changed

- `spriterrific-api`: agents now share the live run page
  (`https://app.spriterrific.com/jobs/<jobId>`) with the user immediately
  after enqueueing, so progress and artifact previews can be watched in the
  browser while the agent polls.

## [1.0.0] - 2026-07-14

### Added

- Initial public release of the `spriterrific-api` skill: drive the hosted
  Spriterrific HTTP API — enqueue character/action sprite jobs, poll status,
  download spritesheets, and manage credits.
- `spriterrific-api-skill.zip` release asset that unzips at a project root
  into both `.claude/skills/` and `.agents/skills/` variants.
- README quick start with three install paths: zip download, a paste-ready
  AI install prompt, and a manual curl.

[Unreleased]: https://github.com/chongdashu/spriterrific-skills/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/chongdashu/spriterrific-skills/releases/tag/v1.0.0
