# Method notes: the dead.garden AM halftone

Source: [dead.garden — "How my images are dithered"](https://dead.garden/blog/how-my-images-are-dithered.html)
(posted from Erfurt, DE; method adapted by the author from a recipe found online, source lost).

## The idea

A screen can vary each pixel's RGB intensity; a printer cannot — it has a
fixed palette of inks and fakes intermediate tones with a **grid of dots**.
Three grid families:

- **AM** (amplitude-modulated): dot *size* varies, positions fixed on a grid.
  Dark spot = big dots. This is what the skill simulates.
- **FM** (frequency-modulated): dot size fixed, dot *count* varies — looks
  chaotic/random.
- **Hybrid**: both.

Naively stacking AM grids per ink produces **moiré** (interference patterns
between the grids). FM grids are random, so they don't suffer from it. For
AM, print practice offsets each ink's grid by a fixed screen angle — DIN
16547 standardizes roughly: Yellow 0°, Cyan 15°, Black 45°, Magenta 75°.

The blog's command applies the angles 0/15/45/75 to the channels in
`-separate` order (C, M, Y, K) — i.e. C 0°, M 15°, Y 45°, K 75° — which does
not exactly match the DIN table above. The author shrugs: "This sets C at
0°, M at 15° etc. But whatever. Zooming in and out doesn't make any weird
artifacts apparent so it's good enough." The skill preserves the author's
exact order.

## Command anatomy

```
convert "oldfile" -resize 800 -set option:distort:viewport '%wx%h+0+0' \
                 -colorspace CMYK -separate null: \
                 \( -size 2x2 xc: \( +clone -negate \) \
                +append \( +clone -negate \) -append \)  \
                -virtual-pixel tile -filter gaussian  \
                \( +clone -distort SRT 2,0 \) +swap  \
                \( +clone -distort SRT 2,15 \) +swap   \
                 \( +clone -distort SRT 2,45 \) +swap  \
                \( +clone -distort SRT 2,75  \) +swap +delete \
                -compose Overlay -layers composite -colors 2 -set colorspace CMYK -combine \
                "newfile"
```

1. `-resize 800` — 800px wide is plenty; the grid swallows fine detail anyway.
2. `-set option:distort:viewport '%wx%h+0+0'` — pin the canvas size so the
   per-channel rotations don't crop or expand it (rotation leaves empty
   corners otherwise).
3. `-colorspace CMYK -separate null:` — convert to CMYK, split into four
   grayscale channel images. (`null:` terminates the separate list.)
4. The parenthesized block builds the threshold tile: a 2×2 black canvas,
   cloned+negated and appended into a checkerboard. (The appends make it
   4×2 in practice; the scale factor absorbs that.)
5. `-virtual-pixel tile` — the tile repeats infinitely as the virtual pixel
   source during distortion. `-filter gaussian` smooths the rotated pattern
   (softens dots, avoids harsh aliasing).
6. Per channel: `+clone` the pristine tile, `-distort SRT <scale>,<angle>`
   scales and rotates the copy, `+swap` restores the pristine tile to the
   top of the stack for the next channel. Final `+swap +delete` drops the
   leftover un-distorted tile. Stack ends as
   `[C, M, Y, K, grid0, grid15, grid45, grid75]`.
7. `-compose Overlay -layers composite` — each rotated checkerboard is laid
   over its channel. This is the tone→dot-grid step.
8. `-colors 2` — **the "true CMYK" fix** (author's edit after sleeping on
   it): quantize each channel to 2 colors *before* recombining, so dots vary
   in size rather than darkness. Without it, zoomed-in squares are just
   darker — not a true halftone imitation.
9. `-set colorspace CMYK -combine` — merge the four binary channels back
   into one CMYK image.

The author's own summary of the steps: convert RGB→CMYK (adding a channel);
split into four and transform each (scale up, invert); limit each to 2
colors; overlay the four; recombine; limit final colors.

## Variants (from the post)

- **Pink, old method** — the blog's original look: same pipeline at scale 2
  (bigger dots), *without* per-channel `-colors 2`, then
  `-colorspace Gray -colors 2 +level-colors black,#A2719B`. The author notes
  it has the most "printy" feel but swallows detail, and abandoned it
  ("also I got sick of looking at it").
- **Pink, new method** — scale 1, no per-channel `-colors 2`, then
  `-remap "$palette" -colors 32`. The palette is a linear gradient through
  the site's colors: white, black, pink, darker pink. More depth, more
  usable on the blog.
- **Problematic (overwhelmingly light) images** — the grid misfires on very
  light images; the author's fallback skips the grid entirely:
  `convert "oldfile" -modulate 300,200,100 -negate -remap $palette "newfile"`
  (the author suspects their palette is partly to blame).
- **RGB** — "You can ofc do the same thing with RGB instead of CMYK. That
  wouldn't really be as accurate for a 'print vibe'!!" Result: darker, more
  intense colors, more detail in places. The skill's `rgb` mode mirrors the
  true-CMYK pipeline in RGB (3 channels, angles 0/15/45); the post gives no
  RGB command, so this is the skill's extension, not the author's.

## The author's batch script (verbatim, cleaned of blog formatting)

Processes every image in the working dir; originals go to `big/`, halftoned
outputs to `smol/`, final `-colors 64` to claw back some file size:

```bash
#!/bin/bash
temp="/tmp/images"
palette="/path/to/palette.png"
mkdir -p smol big
{ ls -r *.webp; ls -r *.png; ls -r *.jpg; ls -r *.jpeg; ls -r *.gif; } > "$temp" 2>/dev/null
cp $(cat "$temp") big/.
i=$(cat "$temp" | wc -l)
while [[ $i -gt 0 ]]; do
  name="$(head -n $i $temp | tail -n +$i)"
  echo "doing $name"
  convert "$name" -set option:distort:viewport '%wx%h+0+0' \
    -colorspace CMYK -separate null: \
    \( -size 2x2 xc: \( +clone -negate \) +append \( +clone -negate \) -append \) \
    -virtual-pixel tile -filter gaussian \
    \( +clone -distort SRT 2,0 \) +swap \
    \( +clone -distort SRT 2,15 \) +swap \
    \( +clone -distort SRT 2,45 \) +swap \
    \( +clone -distort SRT 2,75 \) +swap +delete \
    -compose Overlay -layers composite -colors 2 \
    -set colorspace CMYK -combine \
    -colors 64 "smol/$name"
  (( i-- ))
done
```

`bin/halftone.sh --batch` implements the same `big/`/`smol/` contract in a
safer form (no `rm $temp` footgun, no word-splitting on filenames).

## Caveats (the author's, preserved)

- "If you care about the method this is **not dithering**. Or at least it's
  the most unnecessarily computationally expensive form of dithering I've
  come across." Call it an AM halftone simulation.
- ~10 seconds per big image on an 11-year-old laptop. Not fast.
- Not a file-size strategy: limiting colors + resizing helps, but
  overlaying four grids *creates* new colors and the pattern fights
  compression. (For reference, the author's Floyd–Steinberg comparison image
  was smaller than the pink-method output.)
- The author asks that images of them and their friends not be fed to LLMs:
  develop and test with your own images. The skill's gate generates its own
  test image for exactly this reason.
