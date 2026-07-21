# Changelog

All notable changes to the Spriterrific agent skills are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Every release is tagged and ships a rebuilt `spriterrific-api-skill.zip`
asset (built by `scripts/package.sh`), which is what
`releases/latest/download/spriterrific-api-skill.zip` — and therefore the
app.spriterrific.com download button — serves.

## [Unreleased]

## [1.3.2] - 2026-07-21

### Changed

- `spriterrific-api`: the output-mode gate's pixel-snap option is relabeled
  **"Chunky low-fi on a real pixel grid (lobit)"** and now describes the
  aesthetic honestly: a deliberately simple, low-fidelity distillation
  (compact silhouettes, big pixel clusters) that works best for creatures,
  monsters, and blocky or armored characters — with a note that detailed
  humanoids commonly trip the snap-contract warning.
- `spriterrific-api`: new explicit "not yet served" guidance — classic
  16-bit / arcade fighting-game style (detailed humanoids with preserved
  proportions on a ~100–140px native grid) is not produced by `lobit-v1`
  and agents should not route such requests there. Until the dedicated
  pipeline ships, agents should say so and offer the mixels default as
  today's best result.

## [1.3.1] - 2026-07-21

### Changed

- `spriterrific-api`: documented that jobs with a `referenceJobId` (action
  jobs and character variants) now inherit the reference job's `chroma`
  matte automatically — agents no longer need to re-send it, and
  magenta-matte characters stay keyed against magenta on follow-up
  animations. Pass `chroma` explicitly only to override.

## [1.3.0] - 2026-07-21

### Added

- `spriterrific-api`: **character variant jobs** — edit an existing
  character without losing the character. A character job with
  `referenceJobId` uses that job's anchor as the base image; add
  `editPrompt` describing only the delta ("replace the robes with a white
  hoodie") for an identity-preserving outfit/prop edit, or omit it and set a
  new `direction` to re-face the unchanged design. New "Character Variants"
  section covers delta-writing guidance, and a new anti-pattern warns
  against regenerating variants from text prompts or external image tools
  (which invent a new face and style). Variants cost the same as an
  image-sourced character (2 image generations + actions).
- `spriterrific-api`: **skill version handshake** — the skill now carries a
  `version` in its frontmatter and sends it as
  `X-Spriterrific-Skill-Version` on every request; when a newer skill has
  been released, `GET /api/v1/me` and `POST /api/v1/jobs` responses include
  a `notice` telling the agent the copy is outdated and how to update.
  Agents must surface the notice to the user.

### Changed

- `spriterrific-api`: the recommended fix for "action job needs a facing
  the character doesn't have" is now a variant job (`referenceJobId` +
  `direction`) instead of re-uploading the anchor URL as `sourceImageUrl`.

## [1.2.6] - 2026-07-18

### Changed

- `spriterrific-api`: documented that `sourceImageUrl` must **directly serve
  the image bytes** (`Content-Type: image/*`). Share/preview pages — such as
  tmpfiles.org `/dl/` links or Google Drive / Dropbox share links — return
  HTML and are now rejected by the worker with a clear "returned a web page,
  not an image file" error (previously they crashed the job with a cryptic
  `cannot identify image file`). Prefer hosts that serve raw files (catbox,
  uguu) and mind link expiry (tmpfiles expires in ~60 minutes).

## [1.2.5] - 2026-07-17

### Changed

- `spriterrific-api`: documented that action jobs **cannot change facing** —
  they animate an anchor that already exists on the reference job, and a
  character job produces exactly one direction anchor. A `direction` with no
  matching anchor is now rejected at enqueue with a 400 (previously it
  failed asynchronously on the worker after debiting). To get another
  facing, run a new character job with the desired `direction`, passing the
  existing anchor's artifact `url` as `sourceImageUrl`, then animate that
  job. The `direction` parameter row no longer says "only pass it to
  override".

## [1.2.4] - 2026-07-17

### Changed

- `spriterrific-api`: idle-drift guidance rewritten from a field failure —
  idles need a full-body freeze list ("frozen statue pose, feet glued, no
  stepping, no walking, no foot lift, no arm swing, no weight shift, only a
  tiny breathing bob"), because banning only foot motion pushes drift into
  arm swing and hip sway that still reads as walking. Failed rolls should
  ban each visible motion by name and cap allowed motion with "only …",
  then verify feet and torso enlarged.
- `spriterrific-api`: documented that `actionContext` is job-global — one
  string conditions every action in the job. Never bundle `idle` with
  locomotion actions under a locomotion-flavored context; splitting is
  cost-neutral (character job with idle + separate `action` job costs the
  same as bundling).
- `spriterrific-api`: `actionContext` length guidance relaxed from ~100 to
  ~130 characters (field-verified safe); ~150+ still risks the video
  prompt cap.

## [1.2.3] - 2026-07-16

### Changed

- `spriterrific-api`: hosted video default documented as
  `grok-imagine-video-1.5-i2v` (was `grok-imagine-video-i2v`); prompt-cap
  guidance updated to match. Agents should check
  https://app.spriterrific.com/status before hammering retries during
  provider incidents.

## [1.2.2] - 2026-07-16

### Changed

- `spriterrific-api`: sample character is a chubby orange tabby cat in a
  red hoodie with walk + idle (replaces bunny knight with sword/shield).

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

[Unreleased]: https://github.com/chongdashu/spriterrific-skills/compare/v1.3.1...HEAD
[1.3.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.6...v1.3.0
[1.2.6]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.5...v1.2.6
[1.2.5]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/chongdashu/spriterrific-skills/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/chongdashu/spriterrific-skills/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/chongdashu/spriterrific-skills/releases/tag/v1.0.0
