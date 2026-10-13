---
name: spriterrific-api
description: "Drive the hosted Spriterrific HTTP API from any agent or project: enqueue character/action sprite-generation jobs with CLI-equivalent parameters, create character variants (same character, new outfit or facing), poll job status, re-pick spritesheet frames (Studio frame-picker equivalent), download artifacts, and manage credits. Use when the user wants hosted/cloud sprite generation via API key instead of the local CLI."
version: 1.4.2
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
- character variant job (`referenceJobId`, with or without `editPrompt`):
  `2 × 30 + actions × 100` credits
- action job: `100` credits per action (exactly one action per job)

Always check `GET /api/v1/me` first and tell the user the expected debit.

**Cached example runs.** The app's onboarding example prompt ("a chubby
orange tabby cat in a red hoodie" with walk and/or idle, default options)
is served from a cached run on a user's first request: the enqueue response
says `"cached": true`, the debit is a flat `30` credits, and the job
finishes in about half a minute. Treat it like any other job — poll,
download, frame-pick, and use it as a `referenceJobId` as usual — and tell
the user it was served from cache, which is why it cost less and finished
fast. Later identical requests generate for real at the normal price.

### Skill version handshake (send on every request)

This skill file is a copy in the user's project and never auto-updates, so
the API pushes update hints back. On **every** request, send this skill's
version (from the frontmatter above) as a header:

```bash
-H "X-Spriterrific-Skill-Version: 1.4.2"
```

When your copy is older than the released skill, `GET /api/v1/me` and
`POST /api/v1/jobs` responses include a `notice` string describing what
changed and how to update. If a response carries `notice`, tell the user —
do not silently ignore it. To update: download
`https://github.com/chongdashu/spriterrific-skills/releases/latest/download/spriterrific-api-skill.zip`
and unzip it at the project root (it refreshes both `.claude/skills/` and
`.agents/skills/` copies).

## Endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /api/v1/me` | Credit balance (`planCredits`, `topupCredits`, `total`). |
| `POST /api/v1/jobs` | Enqueue a job. `201` → `{ jobId, credits, cached }`. `400` validation, `401` bad key, `402` not enough credits. |
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
- **`character` variant** (same character, changed): a character job with
  `referenceJobId` instead of a prompt/image. The reference job's anchor
  becomes the base image, so the result stays recognizably the *same
  character*. Two uses:
  - **Edit**: add `editPrompt` describing only the delta ("replace the robes
    with a white hoodie and grey joggers") — face, skin tone, hair,
    proportions, pose, and art style are preserved automatically.
  - **Re-face**: omit `editPrompt` and set a new `direction` to get another
    facing of the unchanged design.
  See "Character Variants" below. Never rebuild a variant from a new text
  prompt or an externally generated lookalike image — that invents a new
  face and art style.
- **`action`**: one extra animation reusing the anchor of a previous
  completed character job (`referenceJobId`). Cheaper than re-running the
  whole character. Use it to add animations later, retry a bad one, or run a
  **custom action name** via `actionBaselines` (see "Custom Actions").
  Omitting `direction` inherits the reference job's facing. Action jobs
  **cannot change facing**: they animate an anchor that already exists on the
  reference job, and a character job produces exactly one direction anchor.
  Requesting any other `direction` is rejected at enqueue with a 400. To get
  another facing (e.g. a south-facing walk from a west-facing character), run
  a **character variant job** with the desired `direction` and the existing
  job as `referenceJobId` — then animate that job.
- **`frame_extract` / `frame_pick`** (curation, auto-enqueued): zero-credit
  worker jobs that re-extract dense frames from archived raw video and
  rebuild a spritesheet. You do not enqueue these via `POST /api/v1/jobs` —
  use the `/frames` and `/picks` routes below.

## Request Parameters (CLI parity)

| API field | CLI equivalent | Notes |
| --- | --- | --- |
| `sourcePrompt` | `--source-prompt` | Exactly one of `sourcePrompt`, `sourceImageUrl`, or `referenceJobId` per character job. |
| `sourceImageUrl` | `--source-image` | Must be a reachable `https:` URL that directly serves the image bytes (`Content-Type: image/*`) — share/preview pages (tmpfiles.org `/dl/` links, Google Drive/Dropbox share links) return HTML and are rejected. Prefer hosts like catbox/uguu that serve raw files, and mind expiry (tmpfiles expires in ~60 min). Saves one generation. |
| `referenceJobId` | — | Action jobs: the character job whose anchor is animated. Character jobs: makes a **variant job** — the reference anchor is the base image (see "Character Variants"). |
| `editPrompt` | `--edit-prompt` | Character variant jobs: identity-preserving edit applied to the base anchor. Describe **only the delta**; everything not named (face, skin tone, hair, proportions, pose, art style) is preserved. ≤1000 chars. |
| `direction` | `--directions` | One of `n, ne, e, se, s, sw, w, nw`. Character jobs default to `w`; variant and action jobs default to the reference job's direction. Action jobs must match an existing anchor (normally: omit it). New facings need a character variant job (see "Job Types"). |
| `gameView` | `--game-view` | `platformer` (default), `adventure`, `point-and-click`, `top-down`, `rts-oblique`, `isometric`, `generic`. |
| `actions` | `--actions` | Standard set: `walk, run, jump, hurt, attack, death, idle, crouch` (best-assured core) plus `talk, interact, pick_up, use, examine, give, shrug, walk_forward, walk_backward, block_high, block_low, knockdown, get_up, light_attack, heavy_attack`. Action jobs take exactly one, and may use a custom name with `actionBaselines`. |
| `actionBaselines` | `--action-baseline` | Action jobs only: map a custom action name to its backing standard action, e.g. `{ "sliding-tackle": "attack" }`. See "Custom Actions". |
| `candidatePromptPreset` | `--candidate-prompt-preset` | `high-fidelity-v1` (hosted default), `lobit-v1` (chunky low-fi distillation — see the mode gate below), `preserve-reference-v1`, `edit-reference-v1` (set automatically when `editPrompt` is present; variants without an `editPrompt` default to `preserve-reference-v1`). |
| `pixelSnapAnchor` | `--pixel-snap-anchor` | Default `false` (hosted default is mixels). |
| `pixelSnap` | `--pixel-snap` | Snap exported animation frames. Default `false`. |
| `seed` | `--seed` | Reproducibility. |
| `actionContext` | `--action-context` | Extra prose for action prompts (props, pose semantics). ≤1000 chars. |
| `chroma` | `--chroma` | Matte color, default `#00FF00`. Jobs with a `referenceJobId` (actions and variants) inherit the reference job's chroma when omitted — do not re-send it. |
| `kColors` | `--k-colors` | Palette quantization, 2–256 (default 256). |
| `actionModes` | `--mode` per action | Do not send. Every hosted action runs in video mode; `"image"` values are rejected with a 400. |
| `imageModelAlias` / `videoModelAlias` | `--image-model` / `--video-model` | Only when the user explicitly wants a model comparison. |

## Choosing Parameters: the Output Mode Gate

Carry over the CLI skill's mode gate. If the user has not chosen, ask briefly:

1. **Mixels / high fidelity** (hosted default): richer AI pixel texture, not a
   recoverable pixel grid. Use `candidatePromptPreset: "high-fidelity-v1"`,
   `pixelSnapAnchor: false`, `pixelSnap: false`. Simplest and safest hosted
   path.
2. **Chunky low-fi on a real pixel grid (lobit)**: a deliberately simple,
   low-fidelity distillation recovered onto a real pixel grid — compact
   silhouettes, big pixel clusters, detail collapsed into one or two cues.
   Works best for creatures, monsters, and blocky or armored characters.
   Use `candidatePromptPreset: "lobit-v1"`, `pixelSnapAnchor: true`,
   `pixelSnap: true`, `kColors: 64`. The lobit snap-contract check is a
   *warning* on the hosted path (surfaced in `steps[].warnings`), not a hard
   failure — relay any warning to the user because it signals the candidate
   came out taller/denser than the style intends (common with detailed
   humanoid characters).

   **Not yet served: "classic 16-bit" / arcade fighting-game style** —
   detailed humanoids with preserved proportions on a ~100–140px native
   grid. Lobit is not that style and will not produce it; a dedicated
   pipeline is in development. If the user asks for 16-bit arcade sprites,
   say so plainly and offer mixels (option 1) as today's best result rather
   than routing the request to lobit.
3. **Reference-preserving**: user says "keep this exact style/proportions" for
   a `sourceImageUrl`. Use `candidatePromptPreset: "preserve-reference-v1"`;
   pixel snapping remains a separate decision.

Other carried-over judgment:

- **Green characters**: if the subject is green, teal, or lime, set
  `chroma: "#FF00FF"` on the *character* job so background keying doesn't eat
  the character. Follow-up action and variant jobs inherit it automatically.
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

## Character Variants (same character, new outfit or facing)

When the user wants an existing character *changed* — a new outfit, a
swapped prop, armor variants, or the same design facing another direction —
enqueue a character job whose source is the previous job:

```json
{
  "type": "character",
  "characterName": "hoodie-cat-street",
  "referenceJobId": "<completed character job id>",
  "editPrompt": "replace the red hoodie with a denim jacket and add white sneakers",
  "actions": ["walk", "idle"]
}
```

The reference job's anchor is downloaded as the base image and edited with
an identity-preserving preset: the face, facial features, expression, skin
tone, hairstyle, body proportions, pose, and rendering style are pinned;
only what the `editPrompt` names changes.

Writing a good `editPrompt`:

- Describe **only the delta**: "replace X with Y", "add Z", "recolor the
  cloak to deep red". Everything you do not mention is preserved.
- Do **not** re-describe the character ("a cat wizard with...") — a full
  description competes with the base image and reintroduces drift.
- One coherent change set per variant. For heavy redesigns (new species,
  different body type), a fresh character job is honest — that *is* a new
  character.

Re-facing without changes: omit `editPrompt` and set `direction` to the new
facing. The design is preserved (`preserve-reference-v1`) while the engine
generates the new-direction anchor. Then animate the new job with `action`
jobs as usual.

**Never** create a variant by writing a new `sourcePrompt` from scratch or
generating a lookalike reference with another image tool and passing it as
`sourceImageUrl`. Field case: an agent regenerated a character externally
for an outfit swap and the result lost the original's face, skin tone, and
art style even though every trait was carefully described. Text prompts
cannot pin identity; the variant path exists precisely for this.

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
SKILL="X-Spriterrific-Skill-Version: 1.4.2"

# 1. Pre-flight: balance vs expected cost. If the response carries a
#    "notice" field, relay it to the user (skill update available).
curl -s -H "$AUTH" -H "$SKILL" "$BASE/api/v1/me"

# 2. Enqueue.
curl -s -X POST -H "$AUTH" -H "$SKILL" -H "Content-Type: application/json" \
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

# 5. Engine 0.21.0+ sheets already hold every frame at 24 fps. Re-pick only
#    older jobs or a loop that hitches — see "Smooth Animation". 0 credits.
#    When reporting a dense mixels animation, offer a lo-fi re-pick once.
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

- For smooth motion, take consecutive frames (every frame of one cycle) at
  24 fps — see "Smooth Animation" below. Skipping frames (every 2nd or 3rd)
  is what makes the automatic 8-frame sheets look choppy; only do it when
  the user wants a limited-animation look.
- For loops, end one frame *before* the pose repeats; including the repeat
  shows the same pose twice and the loop hitches.
- After activate, always re-fetch `GET /api/v1/jobs/{jobId}` before
  downloading — the `url`s on `<action>/spritesheet` change.
- Older jobs without `<action>/raw-video` return `unavailable`; tell the user
  to regenerate that action if they need the picker.

## Smooth Animation: Use Every Frame (default for mixels)

The hosted video is 24 fps (about 2 s and 49 frames for walk and run; about
1 s for idle, jump, and hurt). Every frame of one cycle at 24 fps looks far
smoother than a sparse sample. Field case: a platformer hero's run went
from 8 frames at 12 fps to 16 frames at 24 fps, and its walk from 8 at
10 fps to 24 at 24 fps; the difference in game was large.

- **Jobs with `engineVersion` 0.21.1 or later already do this.** Their
  automatic sheet (`v1`) holds every frame of one measured walk/run cycle,
  or the whole clip for jump, hurt, attack, and other one-shots, at the
  video's fps (12 when the clip doubles every frame). Check
  `<action>/manifest` (`frames`, `fps`) and deliver `v1` as is; re-pick
  only if the loop visibly hitches. Idle and talk stay at their classic
  counts, as do pixel-snapped (lobit) jobs.
- **Engine 0.21.0 jobs** have dense sheets too, and their one-shots are
  fine, but some walk/run loops are a single step (the leading leg swaps
  at every loop) or a frame off. Re-check walk and run loops with the
  recipe below and re-pick when it finds a different cycle.
- **Older jobs (`engineVersion` below 0.21.0 or `null`)** have an 8-frame
  `v1` that skips frames: a walk keeps every 3rd frame of its cycle at
  10 fps, a run every 2nd frame at 12 fps. Unless the user chose lobit /
  pixel snap or wants a choppy, limited-animation look, create a dense
  pick with the recipe below and activate it (0 credits, about a minute
  per action). `v1` stays available; tell the user which version is active.

**Offer a lo-fi version once.** When you deliver a dense mixels animation
(not lobit / pixel-snapped — those already keep classic counts), add one
line to your report, once per session: for example, "The walk is 24
frames at 24 fps; for a choppier retro feel I can re-pick it at 8 frames
/ 8 fps for free, and the smooth version stays available." It is an
offer, not a question: don't wait on an answer, and keep dense as the
recommendation.

To make an animation lo-fi, cut frames and fps by the same factor `N`:
keep every `N`th frame of the same cycle (from `find_cycle` below, which
matches the engine's cycle to within a frame) or of the one-shot range,
and set `fps` to the dense fps ÷ `N` — every 3rd frame at 8 fps, or every
2nd at 12 fps. Choose `N` so the cycle lands near 8–12 frames. Lowering
`fps` alone just plays the same frames in slow motion. A developer can
get the same look in their engine, without a re-pick, by playing every
`N`th frame at fps ÷ `N`.

What to pick (frame names come from `GET …/frames`, in order; pick at most
64 frames, `fps` 1–60):

| Action | Frames | fps |
| --- | --- | --- |
| `walk`, `walk_forward`, `walk_backward` | One cycle starting about 8% into the clip; measure its length (typically 22–24 frames) | 24 |
| `run` | One cycle starting about 20% into the clip; measure its length (typically 14–16 frames) | 24 |
| Other loops (`talk`, custom loops) | One measured cycle | 24 |
| One-shots and transitions (`jump`, `hurt`, `attack`, `death`, …) | Every frame from the start pose to the settled end pose, minus smeared frames and exact repeats | 24, or 12 when the clip doubles every frame |
| `idle` | Keep `v1` unless the clip visibly moves; dense idle frames mostly repeat | — |

Measure the cycle instead of trusting a typical length — it varies per
video (hosted walks have measured 18–31 frames, runs 13–22), and a wrong
length makes the loop pop. A walk or run cycle is **two steps**, and
halfway through it the opposite leg leads in a near-identical silhouette,
so a "most similar frame" search often lands on one step and ships a loop
where the legs swap every cycle. Find the step first — the first dip in
frame similarity — then take the dip nearest twice that:

```python
import io
import subprocess
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageChops, ImageStat


def load_thumb(url: str) -> Image.Image:
    """Download one dense-frame thumbnail as a small grayscale image."""
    data = subprocess.run(["curl", "-s", url], check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(data)).convert("L").resize((64, 64))


def distance(a: Image.Image, b: Image.Image) -> float:
    """Mean pixel difference between two thumbnails."""
    return ImageStat.Stat(ImageChops.difference(a, b)).mean[0]


def find_cycle(urls: list[str], start: int, typical: int) -> tuple[int, int] | None:
    """Return (first_index, length) of one two-step loop cycle, or None if unclear.

    typical is the usual cycle length: 24 for walk, 16 for run.
    """
    with ThreadPoolExecutor(8) as pool:
        thumbs = list(pool.map(load_thumb, urls))
    curve: dict[int, float] = {}
    for k in range(1, round(typical * 1.6) + 1):
        pairs = range(start, len(thumbs) - k)
        if len(pairs) < 6:
            break
        curve[k] = sum(distance(thumbs[i], thumbs[i + k]) for i in pairs) / len(pairs)
    dips = [
        k for k in sorted(curve)
        if k - 1 in curve and k + 1 in curve
        and curve[k] <= min(curve[k - 1], curve[k + 1])
        and curve[k] <= 0.85 * max(curve[j] for j in range(1, k))
    ]
    steps = [k for k in dips if 0.3 * typical <= k <= 0.75 * typical]
    if not steps:
        return None
    cycles = [k for k in dips if 1.6 * steps[0] <= k <= 2.4 * steps[0]]
    if not cycles:
        return None
    estimate = min(cycles, key=lambda k: abs(k - 2 * steps[0]))
    options = [
        (begin, length)
        for length in range(estimate - 2, estimate + 3)
        for begin in range(start, start + estimate // 2 + 1)
        if begin + length < len(thumbs)
    ]
    return min(options, key=lambda o: distance(thumbs[o[0]], thumbs[o[0] + o[1]]))


# frames = GET …/frames → payload["frames"] (each has "name" and "url")
# start = round((len(frames) - 1) * 0.20)   # run; 0.08 for walk
# begin, length = find_cycle([f["url"] for f in frames], start, 16)   # walk: 24
# pick = [f["name"] for f in frames[begin : begin + length]]
```

If `find_cycle` returns None (no clear step, e.g. a near-static clip),
inspect the contact sheet and pick one full two-step cycle by eye.

Then POST the pick with `"fps": 24`, poll the pick job, activate the new
version, re-fetch the job, and download. Open the new `<action>/preview`
GIF and check that the loop closes without a hitch before reporting.

Don't ask the video model for slow motion to get more frames: in testing
it returned a 12 fps clip with fewer distinct frames per cycle than the
normal run. Dense sheets are larger — 24 frames is a 1280×1280 sheet (5
columns × 5 rows of 256 px) against 1280×512 for 8 — which games handle
easily. When wiring into a game, play at the manifest's `fps` and tie
locomotion playback rate to movement speed so feet don't slide.

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
  spend. `cached: true` marks a run served from the cached onboarding
  example (see Credits above).
- `engineVersion` / `workerVersion` on a finished job record which
  spriterrific engine and worker versions ran it (`null` on jobs from before
  version tracking). Quote `engineVersion` when reporting or comparing run
  quality — behavior changes ship as engine releases.
- When the user asks *which model actually ran*, don't guess from this skill:
  fetch the job's `costs` artifact (and `run-index` if needed) — they record
  the real `modelAlias`, `endpointId`, and mode per generation.

## Anti-Patterns

**Anti-pattern: regenerating a character from text (or an external image
tool) to change its outfit.** A new generation invents a new face, skin
tone, and style no matter how carefully the prompt re-describes the
original. Better: a character variant job — `referenceJobId` +
`editPrompt` naming only the change (see "Character Variants").

**Anti-pattern: re-running the whole character to fix one bad animation.**
Better: enqueue a `type: "action"` job with `referenceJobId` — one
generation instead of the full plan. If the video is fine but the *frame
selection* is wrong, use the frame picker (0 credits) instead of regenerating.

**Anti-pattern: regenerating video to fix timing / loop feel.**
Better: inspect `<action>/contact` and `GET …/frames`, POST a pick with a
better selection, activate it. Re-roll video only when the motion itself is
wrong.

**Anti-pattern: delivering an old job's 8-frame sheet as the final
animation for mixels.** Jobs from before engine 0.21.0 skip most of the
video's frames, so motion looks choppy. Better: re-pick every frame of one
cycle at 24 fps (see "Smooth Animation") — free, and far smoother in game.
Keep the 8–12 frame look only for lobit / pixel snap or when the user asks
for it.

**Anti-pattern: lowering `fps` to make a dense animation look lo-fi.**
The same 24 frames at 8 fps play three times slower. Better: re-pick every
3rd frame of the cycle at 8 fps (or every 2nd at 12 fps), so the frame
count and fps drop together and the speed stays the same.

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
