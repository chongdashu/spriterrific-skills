---
name: spriterrific-api
description: "Drive the hosted Spriterrific HTTP API from any agent or project: enqueue character/action sprite-generation jobs with CLI-equivalent parameters, poll job status, re-pick spritesheet frames (Studio frame-picker equivalent), download artifacts, and manage credits. Use when the user wants hosted/cloud sprite generation via API key instead of the local CLI."
metadata:
  short-description: "Hosted Spriterrific generation via HTTP API."
---

# Spriterrific HTTP API

Spriterrific's hosted API turns a text prompt or reference image into
game-ready 2D character anchors and animation spritesheets — the same engine
as the CLI, running on Spriterrific's cloud workers. Use this skill when the
user has an API key and wants generation without a local Spriterrific
checkout, FAL key, or Python environment.

This skill is the API analogue of the `spriterrific` CLI skill. The style and
parameter judgment is the same; only the invocation surface differs.

## Setup

- **Base URL**: `https://courteous-mouse-611.convex.site` (override with
  `SPRITERRIFIC_API_BASE` if the user supplies a different deployment).
- **Auth**: every request needs `Authorization: Bearer sk_...`. The user
  creates a key at app.spriterrific.com — on the Quickstart page or the
  **API keys** page in the top navigation. Expect it in
  `SPRITERRIFIC_API_KEY`; if missing, ask the user for it — never invent or
  hardcode one.
- **Credits**: jobs debit the key owner's balance up front; failed or skipped
  steps are refunded automatically. At hosted defaults each image generation
  (anchor step) costs 30 credits and each video generation (action animation)
  costs 100 credits.

Cost formula, before enqueueing:

- character job from `sourcePrompt`: `3 × 30 + actions × 100` credits
- character job from `sourceImageUrl`: `2 × 30 + actions × 100` credits
- action job: `100` credits per action (exactly one action per job)

Always check `GET /api/v1/me` first and tell the user the expected debit.

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/me` | Credit balance (`planCredits`, `topupCredits`, `total`). |
| `POST /api/v1/jobs` | Enqueue a job. `201` → `{ jobId, credits }`. `400` validation, `401` bad key, `402` not enough credits. |
| `GET /api/v1/jobs?limit=25` | List the key owner's jobs, newest first. |
| `GET /api/v1/jobs/{jobId}` | One job: status, per-step outcomes, warnings, artifacts with download `url`s. |
| `GET /api/v1/jobs/{jobId}/actions/{action}/frames` | Dense-frame thumbnails for the frame picker (`ready` / `not_extracted` / `extracting`). |
| `POST /api/v1/jobs/{jobId}/actions/{action}/frames/extract` | Prepare dense-frame thumbnails from archived raw video (**0 credits**). |
| `POST /api/v1/jobs/{jobId}/actions/{action}/picks` | Create a new spritesheet version from selected frames (**0 credits**). |
| `GET /api/v1/jobs/{jobId}/actions/{action}/picks` | List spritesheet versions (`v1` original, `v2+` picks) with artifact URLs. |
| `POST /api/v1/jobs/{jobId}/actions/{action}/picks/{version}/activate` | Make a version the default `<action>/spritesheet` (metadata only; R2 immutable). |

## Job Types

- **`character`** (the main flow): generates a direction anchor from
  `sourcePrompt` or `sourceImageUrl`, then one animation per entry in
  `actions`. This mirrors CLI `bootstrap-anchors` + `run-actions`/`run`.
- **`action`**: one extra animation reusing the anchor of a previous
  completed character job (`referenceJobId`). Cheaper than re-running the
  whole character. Use it to add animations later, retry a bad one, or run a
  **custom action name** via `actionBaselines` (see "Custom Actions").
  Omitting `direction` inherits the reference job's facing.
- **`frame_extract` / `frame_pick`** (curation, auto-enqueued): zero-credit
  worker jobs that re-extract dense frames from archived raw video and
  rebuild a spritesheet. You do not enqueue these via `POST /api/v1/jobs` —
  use the `/frames` and `/picks` routes below.

## Request Parameters (CLI parity)

| API field | CLI equivalent | Notes |
| --- | --- | --- |
| `sourcePrompt` | `--source-prompt` | Mutually exclusive with `sourceImageUrl`. |
| `sourceImageUrl` | `--source-image` | Must be a reachable `https:` URL. Saves one generation. |
| `direction` | `--directions` | One of `n, ne, e, se, s, sw, w, nw`. Character jobs default to `w`; action jobs default to the reference job's direction (only pass it to override). One direction per job. |
| `gameView` | `--game-view` | `platformer` (default), `adventure`, `point-and-click`, `top-down`, `rts-oblique`, `isometric`, `generic`. |
| `actions` | `--actions` | Standard set: `walk, run, jump, hurt, attack, death, idle, crouch` (best-assured core) plus `talk, interact, pick_up, use, examine, give, shrug, walk_forward, walk_backward, block_high, block_low, knockdown, get_up, light_attack, heavy_attack`. Action jobs take exactly one, and may use a custom name with `actionBaselines`. |
| `actionBaselines` | `--action-baseline` | Action jobs only: map a custom action name to its backing standard action, e.g. `{ "sliding-tackle": "attack" }`. See "Custom Actions". |
| `candidatePromptPreset` | `--candidate-prompt-preset` | `high-fidelity-v1` (hosted default), `lobit-v1`, `preserve-reference-v1`. |
| `pixelSnapAnchor` | `--pixel-snap-anchor` | Default `false` (hosted default is mixels). |
| `pixelSnap` | `--pixel-snap` | Snap exported animation frames. Default `false`. |
| `seed` | `--seed` | Reproducibility. |
| `actionContext` | `--action-context` | Extra prose for action prompts (props, pose semantics). ≤1000 chars. |
| `chroma` | `--chroma` | Matte color, default `#00FF00`. |
| `kColors` | `--k-colors` | Palette quantization, 2–256 (default 256). |
| `actionModes` | `--mode` per action | Do not send. Every hosted action runs in video mode; `"image"` values are rejected with a 400. |
| `imageModelAlias` / `videoModelAlias` | `--image-model` / `--video-model` | Only when the user explicitly wants a model comparison. |

## Choosing Parameters: the Output Mode Gate

Carry over the CLI skill's mode gate. If the user has not chosen, ask briefly:

1. **Mixels / high fidelity** (hosted default): richer AI pixel texture, not a
   recoverable pixel grid. Use `candidatePromptPreset: "high-fidelity-v1"`,
   `pixelSnapAnchor: false`, `pixelSnap: false`. Simplest and safest hosted
   path.
2. **Pixel-snap / real pixels**: stricter low-bit art recovered onto a real
   pixel grid. Use `candidatePromptPreset: "lobit-v1"`,
   `pixelSnapAnchor: true`, `pixelSnap: true`, `kColors: 64`. The lobit
   snap-contract check is a *warning* on the hosted path (surfaced in
   `steps[].warnings`), not a hard failure — relay any warning to the user
   because it signals the candidate came out taller/denser than the style
   intends.
3. **Reference-preserving**: user says "keep this exact style/proportions" for
   a `sourceImageUrl`. Use `candidatePromptPreset: "preserve-reference-v1"`;
   pixel snapping remains a separate decision.

Other carried-over judgment:

- **Green characters**: if the subject is green, teal, or lime, set
  `chroma: "#FF00FF"` so background keying doesn't eat the character.
- **Walk that reads like a run**: use `actionContext` for pose semantics
  ("slow relaxed walk, upright torso, no sprint lean") rather than re-rolling
  blindly.
- **`actionContext` is job-global**: the one context string conditions
  *every* action in the job. Never bundle `idle` with locomotion actions
  while the context carries locomotion semantics ("one foot always on
  ground") — the idle absorbs them and walks in place. Split instead; it is
  cost-neutral: bundling idle + walk in one character job costs the same as
  idle in the character job plus a separate `action` job for walk, and each
  job gets a context scoped to its own motion.
- **Idle drift**: give idles a full-body freeze list, not just "stand
  still". Field-tested recipe: "frozen statue pose, feet glued, no
  stepping, no walking, no foot lift, no arm swing, no weight shift, only a
  tiny breathing bob" (130 chars, prompt-cap safe). Partial freezes fail
  sideways — banning only foot motion pushes the drift into arm swing and
  hip sway that still reads as walking. If a roll still drifts, name each
  motion visible in the failed artifact and ban it explicitly, and budget
  the allowed motion with "only …". Context steers but does not guarantee
  (video generation is stochastic), so inspect the result's feet and torso
  enlarged before delivering — whole-sheet glances miss stepping. The image
  pose-board fallback was retired from the hosted service; every action
  runs in video mode.
- **Video prompt cap**: hosted actions run in video mode, and the
  grok-imagine-video-1.5-i2v prompt cap is 4096 characters. Some action
  prompts (idle especially) sit near that cap already, so keep
  `actionContext` short — up to ~130 characters is field-verified safe,
  ~150+ can overflow. A prompt-cap failure is refunded; shorten the context
  and retry.
- **Adventure characters**: `gameView: "adventure"`, `direction: "sw"`.
- **Model choices**: hosted defaults (nano-banana-2-lite image,
  grok-imagine-video-1.5-i2v video) are deliberate; only override aliases
  for an explicit comparison.
- **Provider incidents**: if video jobs fail or stall broadly, check
  https://app.spriterrific.com/status before retrying the same request
  repeatedly. Failed steps still auto-refund.

## Custom Actions (baseline + label)

The standard actions are the best-assured vocabulary, not a ceiling. When
the user needs a domain move that isn't a standard action (kick, sliding
tackle, celebrate, cast-spell, …), enqueue an `action` job with the custom
name and a `actionBaselines` entry mapping it to the closest standard
action:

```json
{
  "type": "action",
  "characterName": "dog-footballer",
  "referenceJobId": "<completed character job id>",
  "actions": ["sliding-tackle"],
  "actionBaselines": { "sliding-tackle": "attack" },
  "actionContext": "low aggressive slide along the ground, leading leg extended"
}
```

- The **baseline** supplies the engine preset (timing, frame counts, fps,
  prompt family). Pick the standard action whose motion family is closest:
  `attack` / `light_attack` / `heavy_attack` for offensive contact moves,
  `hurt` for reactions, `interact` / `use` for object handling, `idle` for
  poses/stances, `jump` for airborne moves.
- The **custom name** labels everything: the step id (`action:sliding-tackle`)
  and all artifact paths (`sliding-tackle/spritesheet`, `sliding-tackle/preview`,
  …), so two moves derived from the same baseline (e.g. `kick` and
  `sliding-tackle`, both from `attack`) never overwrite each other.
- Custom names must be lowercase slugs, ≤40 chars (`a-z`, `0-9`, `-`, `_`),
  can't reuse a standard action name, and can't be `anchors`, `export`,
  `input`, or `frames`.
- Always pair a custom action with a short `actionContext` describing the
  motion — the baseline provides structure, the context provides the verb's
  specifics. The ~100-character video prompt-cap guidance applies.
- Custom actions are single `action` jobs only (character jobs accept only
  standard actions). Quality is steered, not preset-tuned: standard actions
  remain the assured-quality set, so prefer them when one fits.

## Recommended Agent Loop

```bash
BASE=${SPRITERRIFIC_API_BASE:-https://courteous-mouse-611.convex.site}
AUTH="Authorization: Bearer $SPRITERRIFIC_API_KEY"

# 1. Pre-flight: balance vs expected cost.
curl -s -H "$AUTH" "$BASE/api/v1/me"

# 2. Enqueue.
curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "type": "character",
    "characterName": "hoodie-cat",
    "sourcePrompt": "a chubby orange tabby cat in a red hoodie",
    "gameView": "platformer",
    "direction": "w",
    "actions": ["walk", "idle"]
  }' "$BASE/api/v1/jobs"

# 3. Share the live run page with the user, then poll every ~15s until
#    status is terminal (completed | partial | failed | canceled).
echo "Watch live: https://app.spriterrific.com/jobs/$JOB_ID"
curl -s -H "$AUTH" "$BASE/api/v1/jobs/$JOB_ID"

# 4. Download artifacts by their `url` field into the local run folder
#    (see "Save Artifacts Locally" below).

# 5. (Optional) Re-pick frames if the auto-selection looks wrong — see
#    "Frame Picker" below. Free; no fal.ai cost.
```

As soon as the enqueue returns a `jobId`, give the user the run's live page
— `https://app.spriterrific.com/jobs/<jobId>` — so they can watch
step-by-step progress and artifact previews in the browser while you poll.
Don't make them wait blind through a multi-minute job. The run page also
hosts the interactive frame picker once an action finishes.

Jobs take minutes (one provider generation per anchor step and per action),
so poll patiently — don't tight-loop. A `progress` object on the job shows
the current step and index/total while running (it may be `null` once the
job finishes — rely on `status` and `steps`, not `progress`).

**Response envelope:** `GET /api/v1/jobs/{jobId}` wraps everything under a
top-level `"job"` key — there is no top-level `status`:

```json
{ "job": { "id": "...", "status": "partial", "steps": [...], "artifacts": [...] } }
```

Always read `payload["job"]["status"]`, `["job"]["steps"]`,
`["job"]["artifacts"]`, and `["job"]["creditsDebited"]` /
`["job"]["creditsRefunded"]`. Reading top-level `status` returns nothing and
makes a poller loop forever past a finished job.

## Frame Picker (Studio / CLI equivalent, 0 credits)

Hosted video actions keep the archived provider MP4 (`<action>/raw-video`)
and a contact sheet (`<action>/contact`). Newer jobs also upload dense-frame
thumbnails (`<action>/frames-index`). Use these when the auto-selected
spritesheet looks wrong (bad timing, missing pose, uneven spacing) instead
of re-rolling the whole video generation.

This is the API analogue of Studio's Frames tab and CLI
`frame-picker` + `process-selection`. Versions are immutable in R2;
**activate** only rewrites the source job's artifact *names* so
`<action>/spritesheet` etc. point at the active version.

```bash
ACTION=walk

# Inspect whether dense frames are ready.
curl -s -H "$AUTH" "$BASE/api/v1/jobs/$JOB_ID/actions/$ACTION/frames"
# If status is "not_extracted":
curl -s -X POST -H "$AUTH" \
  "$BASE/api/v1/jobs/$JOB_ID/actions/$ACTION/frames/extract"
# Poll the returned extract jobId, then GET …/frames again.

# Create v2 from chosen dense frame names (from the frames list).
curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "frames": ["frame-0002.png","frame-0008.png","frame-0014.png","frame-0020.png","frame-0026.png","frame-0032.png","frame-0038.png","frame-0044.png"],
    "fps": 10
  }' "$BASE/api/v1/jobs/$JOB_ID/actions/$ACTION/picks"
# → { "pickJobId": "...", "version": 2 }
# Poll GET /api/v1/jobs/$PICK_JOB_ID until completed.

curl -s -H "$AUTH" "$BASE/api/v1/jobs/$JOB_ID/actions/$ACTION/picks"
curl -s -X POST -H "$AUTH" \
  "$BASE/api/v1/jobs/$JOB_ID/actions/$ACTION/picks/2/activate"

# Canonical artifact names now point at v2 — re-download spritesheet/preview.
curl -s -H "$AUTH" "$BASE/api/v1/jobs/$JOB_ID"
```

Judgment tips (same as Studio):

- Prefer even spacing between a clear start pose and end pose for loops.
- Keep frame counts near the action preset (often 6–8); extremes look choppy
  or wasteful.
- After activate, always re-fetch `GET /api/v1/jobs/{jobId}` before
  downloading — the `url`s on `<action>/spritesheet` change.
- Older jobs without `<action>/raw-video` return `unavailable`; tell the user
  to regenerate that action if they need the picker.

## Save Artifacts Locally (required)

Always download the useful artifacts into the user's working directory when a
job finishes — never leave the results as remote URLs only. The R2 URLs are
convenient but the user's project needs local files it can commit, edit, and
load in a game engine.

Layout, under the project the user is working in:

```text
spriterrific-runs/<characterName>-<jobId-suffix>/
  anchor-w.png            # anchors/anchor-<direction>
  candidate.png           # anchors/candidate (when present)
  <action>/spritesheet.png
  <action>/preview.gif
  <action>/manifest.json
  job.json                # the final GET /api/v1/jobs/{id} response
```

Use the last 8 characters of the job id as the suffix to keep folder names
short but unique. Download each artifact via its `url`:

```bash
RUN_DIR="spriterrific-runs/${NAME}-${JOB_ID: -8}"
mkdir -p "$RUN_DIR/walk"
curl -s -o "$RUN_DIR/walk/spritesheet.png" "<walk/spritesheet url>"
curl -s -o "$RUN_DIR/walk/preview.gif"     "<walk/preview url>"
curl -s -o "$RUN_DIR/walk/manifest.json"   "<walk/manifest url>"
curl -s -o "$RUN_DIR/anchor-w.png"         "<anchors/anchor-w url>"
```

Download with `curl` — plain `urllib.request` (default Python User-Agent)
can get `403` from the public R2 URLs even though `curl` succeeds. If you
must use Python, send a browser-like `User-Agent` header or shell out to
curl.

Save `job.json` too so the run is reproducible (job id, parameters, steps,
costs). Skip the bulky extras (`raw-video`, `contact`, `run-index`) unless
the user wants to re-pick frames later — mention they exist and where.

After downloading, point the user at both surfaces: the local folder for
their project, and the run's page on the web app
(`https://app.spriterrific.com/jobs/<jobId>`) for in-browser preview of the
spritesheet, GIF, and raw video.

## Reading Results

- `status: "partial"` means some steps failed and were refunded; the rest
  produced artifacts. Report which steps failed (`steps[].error`) and offer a
  follow-up `action` job with `referenceJobId` to retry just those.
- `steps[].warnings` carries engine quality advisories (e.g. the lobit snap
  contract). Surface them; don't silently ignore.
- Key artifact names: `anchors/anchor-<direction>` (the canonical anchor),
  `<action>/spritesheet` (256×256-cell runtime sheet), `<action>/preview`
  (GIF), `<action>/manifest` (frame metadata JSON), `<action>/contact`
  (auto-selection contact sheet), `<action>/raw-video` (provider video for
  re-picks), `<action>/frames-index` (dense-frame thumbnail index),
  `run-index` (full archived run tree).
- `creditsDebited` / `creditsRefunded` on the job tell the user the true
  spend.
- `engineVersion` / `workerVersion` on a finished job record which
  spriterrific engine and worker versions ran it (`null` on jobs from before
  version tracking). Quote `engineVersion` when reporting or comparing run
  quality — behavior changes ship as engine releases.
- When the user asks *which model actually ran*, don't guess from this skill:
  fetch the job's `costs` artifact (and `run-index` if needed) — they record
  the real `modelAlias`, `endpointId`, and mode per generation.

## Anti-Patterns

**Anti-pattern: re-running the whole character to fix one bad animation.**
Better: enqueue a `type: "action"` job with `referenceJobId` — one
generation instead of the full plan. If the video is fine but the *frame
selection* is wrong, use the frame picker (0 credits) instead of regenerating.

**Anti-pattern: regenerating video to fix timing / loop feel.**
Better: inspect `<action>/contact` and `GET …/frames`, POST a pick with a
better selection, activate it. Re-roll video only when the motion itself is
wrong.

**Anti-pattern: treating hosted output as snap-ready pixel art by default.**
Better: hosted defaults are mixels (`high-fidelity-v1`, no snapping). Only
claim real-pixel-grid output when the job ran with the pixel-snap
parameters, and relay any snap-contract warnings.

**Anti-pattern: forcing a domain move into a standard action's identity.**
Better: don't spend `attack` or `hurt` on a kick or a slide and then juggle
local folder aliases — use a custom action (`actions: ["kick"]`,
`actionBaselines: { "kick": "attack" }`) so the artifacts carry the real
name and the standard slots stay free for their own motions.

**Anti-pattern: burning credits on validation errors you could catch first.**
Better: the API validates before debiting (400s cost nothing), but check the
allowed values in this skill and the balance via `/api/v1/me` before
enqueueing so the user isn't surprised by a 402.

**Anti-pattern: polling in a tight loop or holding the session hostage.**
Better: poll every ~15s; for long action lists, tell the user the expected
duration and check back.

**Anti-pattern: handing the user raw R2 URLs as the deliverable.**
Better: download spritesheets, previews, manifests, and the anchor into
`spriterrific-runs/<name>-<jobId-suffix>/` in their project (see "Save
Artifacts Locally"), and link the run's web page for in-browser viewing.

## Relationship to Other Surfaces

- The **CLI skill** (`spriterrific`) is for local checkouts with review gates
  (frame picker GUI, viewer, size contracts). The hosted API now exposes the
  same frame-pick / version / activate flow via `/frames` and `/picks`
  (and the web run page's Frame picker panel).
- The **web app** (app.spriterrific.com) is the human UI over the same queue;
  jobs enqueued via API appear there too, and API keys are managed there.
- Full endpoint reference: `spriterrific-app/docs/http-api.md` (internal).
