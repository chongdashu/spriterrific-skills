# Changelog

All notable changes to the Spriterrific agent skills are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Every release is tagged and ships a rebuilt `spriterrific-api-skill.zip`
asset (built by `scripts/package.sh`), which is what
`releases/latest/download/spriterrific-api-skill.zip` — and therefore the
app.spriterrific.com download button — serves.

## [Unreleased]

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

[Unreleased]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/chongdashu/spriterrific-skills/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/chongdashu/spriterrific-skills/releases/tag/v1.0.0
