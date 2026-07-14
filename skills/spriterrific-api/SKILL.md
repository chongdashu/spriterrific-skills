---
name: spriterrific-api
description: "Drive the hosted Spriterrific HTTP API from any agent or project: enqueue character/action sprite-generation jobs with CLI-equivalent parameters, poll job status, download spritesheet artifacts, and manage credits. Use when the user wants hosted/cloud sprite generation via API key instead of the local CLI."
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
  creates a key at app.spriterrific.com under **API keys** (top bar). Expect
  it in `SPRITERRIFIC_API_KEY`; if missing, ask the user for it — never
  invent or hardcode one.
- **Credits**: jobs debit the key owner's balance up front; failed or skipped
  steps are refunded automatically. At hosted defaults each
  image generation (anchor step) costs 30 credits and each video generation
  (action animation) costs 100 credits.

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

## Job Types

- **`character`** (the main flow): generates a direction anchor from
  `sourcePrompt` or `sourceImageUrl`, then one animation per entry in
  `actions`. This mirrors CLI `bootstrap-anchors` + `run-actions`/`run`.
- **`action`**: one extra animation reusing the anchor of a previous
  completed character job (`referenceJobId`). Cheaper than re-running the
  whole character. Use it to add animations later or retry a bad one.

## Request Parameters (CLI parity)

| API field | CLI equivalent | Notes |
| --- | --- | --- |
| `sourcePrompt` | `--source-prompt` | Mutually exclusive with `sourceImageUrl`. |
| `sourceImageUrl` | `--source-image` | Must be a reachable `https:` URL. Saves one generation. |
| `direction` | `--directions` | One of `n, ne, e, se, s, sw, w, nw`. Default `w`. One direction per job. |
| `gameView` | `--game-view` | `platformer` (default), `adventure`, `point-and-click`, `top-down`, `rts-oblique`, `isometric`, `generic`. |
| `actions` | `--actions` | From `walk, run, jump, hurt, attack, death, idle, crouch`. |
| `candidatePromptPreset` | `--candidate-prompt-preset` | `high-fidelity-v1` (hosted default), `lobit-v1`, `preserve-reference-v1`. |
| `pixelSnapAnchor` | `--pixel-snap-anchor` | Default `false` (hosted default is mixels). |
| `pixelSnap` | `--pixel-snap` | Snap exported animation frames. Default `false`. |
| `seed` | `--seed` | Reproducibility. |
| `actionContext` | `--action-context` | Extra prose for action prompts (props, pose semantics). ≤1000 chars. |
| `chroma` | `--chroma` | Matte color, default `#00FF00`. |
| `kColors` | `--k-colors` | Palette quantization, 2–256 (default 256). |
| `actionModes` | `--mode` per action | Hosted default is `"video"` for **every** action; omit the field unless the user explicitly wants an action on the image path, e.g. `{ "idle": "image" }`. |
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
- **Idle drift**: demand a closed loop in `actionContext` ("exact start pose
  and exact return to the same start pose for a clean loop; no stepping, no
  foot lift"). As a last resort, `actionModes: { "idle": "image" }` cannot
  travel — but image mode is an opt-in anti-drift tactic, not the default;
  hosted actions run in video mode unless you set `"image"` explicitly.
- **Video prompt cap**: hosted actions run in video mode, and the
  grok-imagine-video-i2v prompt cap is 4096 characters. Some action prompts
  (idle especially) sit near that cap already, so keep `actionContext`
  short — roughly 100 characters is safe, ~150+ can overflow. A prompt-cap
  failure is refunded; shorten the context and retry.
- **Adventure characters**: `gameView: "adventure"`, `direction: "sw"`.
- **Model choices**: hosted defaults (nano-banana-2-lite image,
  grok-imagine-video-i2v video) are deliberate; only override aliases for an
  explicit comparison.

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
    "characterName": "bunny-knight",
    "sourcePrompt": "a small bunny knight with a wooden sword and round shield",
    "gameView": "platformer",
    "direction": "w",
    "actions": ["walk", "idle", "attack"],
    "actionContext": "keeps the wooden sword in the right paw at all times"
  }' "$BASE/api/v1/jobs"

# 3. Share the live run page with the user, then poll every ~15s until
#    status is terminal (completed | partial | failed | canceled).
echo "Watch live: https://app.spriterrific.com/jobs/$JOB_ID"
curl -s -H "$AUTH" "$BASE/api/v1/jobs/$JOB_ID"

# 4. Download artifacts by their `url` field into the local run folder
#    (see "Save Artifacts Locally" below).
```

As soon as the enqueue returns a `jobId`, give the user the run's live page
— `https://app.spriterrific.com/jobs/<jobId>` — so they can watch
step-by-step progress and artifact previews in the browser while you poll.
Don't make them wait blind through a multi-minute job.

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
  (GIF), `<action>/manifest` (frame metadata JSON), `<action>/raw-video`
  (provider video, useful for future re-picks), `run-index` (full archived
  run tree).
- `creditsDebited` / `creditsRefunded` on the job tell the user the true
  spend.
- When the user asks *which model actually ran*, don't guess from this skill:
  fetch the job's `costs` artifact (and `run-index` if needed) — they record
  the real `modelAlias`, `endpointId`, and mode per generation.

## Anti-Patterns

**Anti-pattern: re-running the whole character to fix one bad animation.**
Better: enqueue a `type: "action"` job with `referenceJobId` — one
generation instead of the full plan.

**Anti-pattern: treating hosted output as snap-ready pixel art by default.**
Better: hosted defaults are mixels (`high-fidelity-v1`, no snapping). Only
claim real-pixel-grid output when the job ran with the pixel-snap
parameters, and relay any snap-contract warnings.

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
  (frame picker, viewer, size contracts). The API has no interactive review:
  selection and normalization use engine auto-defaults.
- The **web app** (app.spriterrific.com) is the human UI over the same queue;
  jobs enqueued via API appear there too, and API keys are managed there.
- Full endpoint reference: `spriterrific-app/docs/http-api.md` (internal).
