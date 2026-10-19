---
name: am-halftone
description: Simulate a printed AM halftone dot grid on a digital image (ImageMagick CMYK-channel recipe, after dead.garden). Use when an image needs a print/halftone dot-grid look. Not for real dithering or file-size reduction.
---

# AM Halftone

## When to use

Use when the user wants the printed-halftone dot-grid look on an image —
blog art, zine graphics, offset-print vibe. Do **not** use for actual
dithering, palette reduction where fidelity matters, or shrinking files:
the grid swallows detail and fights compression.

Method: [dead.garden — "How my images are dithered"](https://dead.garden/blog/how-my-images-are-dithered.html).
Full pipeline anatomy lives in `references/method.md` — read it only if you
need to *change* the recipe, not to run it.

## Workflow

### 1. State the plan (before running anything)

Say: input file, mode, width, dot scale, contrast. Defaults: `--width 800`,
`--scale 2`, `--contrast 0`, mode `truecmyk`. The grid eats detail — wider than 800 buys
little, and scale 2 doubles dot size. `--contrast` (sigmoidal, 4–6 is punchy)
goes before the channel split and gives the grid more dot-size variation;
0 keeps the blog-faithful flat look. If the user didn't specify, state the
defaults and proceed; ask only if the choice changes the outcome.

| Mode | Output |
|---|---|
| `truecmyk` (default) | Four rotated CMYK grids, binary channels — most print-accurate |
| `pink-old` | Black + one pink (`#A2719B`), big dots — the blog's original look |
| `pink-palette` | Remapped to white→black→pink→darker-pink gradient, 32 colors |
| `light-fix` | No grid; the author's fallback for overwhelmingly light images |
| `rgb` | Same pipeline in RGB — less print-accurate, more intense |

### 2. Run it

```bash
bin/halftone.sh --in <file> --out <file> --mode <mode> [--width 800] [--scale 2]
bin/halftone.sh --batch <dir>   # originals -> big/, outputs -> smol/
```

Auto-detects `magick` (IM7) / `convert` (IM6), falling back to the
persistent conda-forge install at `~/workspace/imagemagick`.

### 3. Verify with evidence (non-negotiable)

A zero exit code from `halftone.sh` is not evidence the grid formed. Run the
gate and check your actual output:

```bash
bin/check.py
magick <out> -format "%k unique colors, %wx%h\n" info:
```

`check.py` renders every grid mode on a generated test image and asserts the
color budgets the method promises: truecmyk ≤ 16, pink-old exactly 2,
pink-palette ≤ 32. Your output must sit inside its mode's budget at the
requested width.

### 4. Look at the picture

Open the output at 100%+ zoom and confirm tone is carried by dot **size**,
not just darkness — that is the entire point of the method. A thumbnail
cannot tell you this.

**Exit criterion:** output exists at the requested path, at the requested
width, inside the mode's color budget, and the dot grid is visually
confirmed. Until all four hold, the task is not done.

## Anti-rationalization table

| Excuse | Rebuttal |
|---|---|
| "The command exited 0, that's enough." | Exit codes don't prove the grid formed. Color count plus a visual check, or it didn't happen. |
| "Looks right in the thumbnail." | Thumbnails can't show dot-size modulation. Zoom to 100%+. |
| "I'll tune the flags to shrink the file." | Not a file-size tool — the author measured this and it loses. Don't optimize what the method can't do. |
| "I'll test with the blog's dinner photo." | The author explicitly asks that their photos not be fed to LLMs. Generate test images with ImageMagick. |
| "The angles don't match DIN 16547; let me fix them." | The author's order is proven visually ("good enough"). Don't refactor what isn't broken. |
| "Pink needs my brand color; I'll eyeball the hex." | Derive it: darker pink is the pink at 60% brightness, not a guess. The default palette builds from documented stops. |

## Tooling

- `bin/halftone.sh` — the recipe (`--in --out --mode [--width] [--scale] [--contrast] [--palette] [--colors] [--pink]`, or `--batch`)
- `bin/check.py` — executable gate, exits non-zero on failure
- `references/method.md` — pipeline anatomy, moiré/screen-angle background, author's batch script

## Available connectors

- Use `muse.connector_search` to find other connectors and `muse.skill_search` to find related skills.

- If nothing here fits, look on the web for a maintained API or MCP server and set it up with [Custom Connectors and MCPs](/opt/muse/skills/custom-connector-setup/SKILL.md), or build a custom connector.
