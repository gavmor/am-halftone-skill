# AM Halftone

Simulate a printed AM (amplitude-modulated) halftone dot grid on a digital image: split into CMYK channels, overlay a rotated 2×2 checkerboard threshold tile on each channel at print screen angles, recombine — so tone is carried by dot *size*, like ink on paper. True-CMYK variant, pink monochrome variants, and an RGB variant.

**Method:** [dead.garden — "How my images are dithered"](https://dead.garden/blog/how-my-images-are-dithered.html)

## Purpose

Give a digital image the look of a print halftone — per-channel dot grids whose dot size (not darkness) carries the tone. This is an aesthetic effect. The method's author stresses it is **not real dithering and not an efficient way to shrink images** (on their 11-year-old laptop it takes ~10 seconds per big image, and the pattern fights compression).

Use it for: blog/site imagery with a printed vibe, zine graphics, diegetic documents that should feel offset-printed. Do not use it for: actual dithering, palette reduction where fidelity matters (the grid swallows detail, especially at dot scale 2), or anything where file size is the goal.

## Quick start

```bash
bin/halftone.sh --in photo.jpg --out photo-halftone.png --mode truecmyk
bin/halftone.sh --in photo.jpg --out photo-pink.png  --mode pink-palette
bin/halftone.sh --batch ./shoot            # big/ originals, smol/ outputs
bin/check.py                               # executable gate
```

## The pipeline

The core ImageMagick recipe (author's command, parameterized in `bin/halftone.sh`):

```
convert in -resize 800 -set option:distort:viewport '%wx%h+0+0' \
  -colorspace CMYK -separate null: \
  \( -size 2x2 xc: \( +clone -negate \) +append \( +clone -negate \) -append \) \
  -virtual-pixel tile -filter gaussian \
  \( +clone -distort SRT <scale>,0  \) +swap \
  \( +clone -distort SRT <scale>,15 \) +swap \
  \( +clone -distort SRT <scale>,45 \) +swap \
  \( +clone -distort SRT <scale>,75 \) +swap +delete \
  -compose Overlay -layers composite -colors 2 -set colorspace CMYK -combine \
  out
```

- `-resize 800`: the grid eats detail; wider buys little. Default 800px.
- The viewport pin keeps the canvas fixed through the per-channel rotations.
- `-separate` splits CMYK into four channel images; the parenthesized block builds a checkerboard threshold tile; each channel gets a copy of the tile, scaled (`<scale>`: 2 = big dots, 1 = fine) and rotated.
- Angles 0/15/45/75 are the print-screen convention — DIN 16547 exists precisely because naively stacked AM grids produce moiré. The author admits their ordering is approximate ("good enough").
- `-compose Overlay -layers composite` lays each rotated grid over its channel — the tone→dot-grid step.
- `-colors 2` per channel is the author's "true CMYK" fix: binary channels, so dots vary in **size** rather than darkness.

Full anatomy, angle background, and the author's batch script: `references/method.md`.

## Modes

| Mode | What it does | When |
|---|---|---|
| `truecmyk` (default) | Above: four rotated CMYK grids, binary channels | The most print-accurate result |
| `pink-old` | Scale 2, no per-channel `-colors 2`, then `-colorspace Gray -colors 2 +level-colors black,#A2719B` | The old blog look: black + one pink, big dots. Most "printy" but swallows detail; the author abandoned it |
| `pink-palette` | Scale 1, then `-remap palette.png -colors 32` | More depth via a white→black→pink→darker-pink palette gradient |
| `light-fix` | Skips the grid entirely: `-modulate 300,200,100 -negate -remap palette.png` | Overwhelmingly light images, where the grid misfires |
| `rgb` | Same pipeline in RGB (3 channels, angles 0/15/45) | Less print-accurate, darker and more intense, keeps more detail in places |

Options: `--width` (default 800), `--scale` (default 2), `--palette` (default: auto-generated from the blog's documented stops), `--colors` (default 32), `--pink` (default `#A2719B`). Auto-detects `magick` (IM7) vs `convert` (IM6).

## Operating rules

1. Frame it honestly: an AM halftone simulation, not dithering. Say so when asked what it does.
2. Expect ~10s per large image on modest hardware; batch with `--batch`.
3. Never promise smaller files — overlaying four grids creates new colors and fights compression. (The author's own batch ends with `-colors 64` to claw some back.)
4. Test images for development must be self-made (e.g. IM-generated gradients) — the blog author explicitly asks that their photos not be fed to LLMs. `bin/check.py` builds its own test image.
5. Keep originals: `--batch` copies inputs to `big/` and writes outputs to `smol/`, mirroring the author's script.

## Tooling

- `bin/halftone.sh` — the recipe as a script: `--in --out --mode truecmyk|pink-old|pink-palette|light-fix|rgb [--width 800] [--scale 2] [--palette f] [--colors 32] [--pink '#A2719B'] [--batch dir]`.
- `bin/check.py` — executable gate: ImageMagick present → build a self-made gradient test image → run `truecmyk`, `pink-old`, and `pink-palette` → assert valid outputs with the expected color counts (≤16, exactly 2, ≤32). Exits non-zero on failure.
- `references/method.md` — full annotated walkthrough, moiré/screen-angle background, and the author's original batch script.

## Available connectors

- Use `muse.connector_search` to find other connectors and `muse.skill_search` to find related skills.

- If nothing here fits, look on the web for a maintained API or MCP server and set it up with [Custom Connectors and MCPs](/opt/muse/skills/custom-connector-setup/SKILL.md), or build a custom connector.
