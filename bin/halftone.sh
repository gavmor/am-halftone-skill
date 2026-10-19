#!/usr/bin/env bash
#
# halftone.sh -- AM halftone dot-grid simulation, after dead.garden's
# "How my images are dithered"
# (https://dead.garden/blog/how-my-images-are-dithered.html)
#
# Splits the image into CMYK (or RGB) channels, overlays a rotated 2x2
# checkerboard threshold tile on each channel at print screen angles, and
# recombines -- so tone is carried by dot SIZE, like an AM print halftone.
#
# This is an aesthetic effect, not real dithering and not a file-size win.
#
# Usage:
#   halftone.sh --in FILE --out FILE --mode truecmyk|pink-old|pink-palette|light-fix|rgb
#               [--width 800] [--scale 2] [--palette FILE] [--colors 32]
#               [--pink '#A2719B']
#   halftone.sh --batch DIR   # process every image in DIR: originals -> big/, outputs -> smol/
#
set -euo pipefail

MODE="truecmyk"
IN=""; OUT=""; BATCH=""
WIDTH=800; SCALE=2; PALETTE=""; COLORS=32; PINK="#A2719B"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2"; shift 2;;
    --in)      IN="$2"; shift 2;;
    --out)     OUT="$2"; shift 2;;
    --batch)   BATCH="$2"; shift 2;;
    --width)   WIDTH="$2"; shift 2;;
    --scale)   SCALE="$2"; shift 2;;
    --palette) PALETTE="$2"; shift 2;;
    --colors)  COLORS="$2"; shift 2;;
    --pink)    PINK="$2"; shift 2;;
    *) echo "halftone.sh: unknown option $1" >&2; exit 1;;
  esac
done

pick_im() {
  if command -v magick >/dev/null 2>&1; then echo magick
  elif command -v convert >/dev/null 2>&1; then echo convert
  # Persistent conda-forge install (survives VM replacement; see AGENTS.md).
  elif [[ -x "$HOME/workspace/imagemagick/bin/magick" ]]; then echo "$HOME/workspace/imagemagick/bin/magick"
  else echo "halftone.sh: need ImageMagick (magick or convert) on PATH" >&2; exit 1; fi
}
IM="$(pick_im)"

# Build the default palette: smooth white -> black -> pink -> darker-pink
# gradient, from the blog's documented stops (darker pink is derived from the
# pink at 60% brightness, not invented).
gen_palette() {
  local dark
  dark="$("$IM" -size 1x1 "xc:$PINK" -modulate 60,100 txt: | grep -oE '#[0-9A-Fa-f]{6}' | head -1)"
  "$IM" \( -size 85x16 "gradient:#FFFFFF-#000000" \) \
        \( -size 85x16 "gradient:#000000-$PINK" \) \
        \( -size 86x16 "gradient:$PINK-$dark" \) \
        +append "$1"
}

# Core AM-grid transform. Args: in out colorspace scale binary2(0/1) angles...
# then any extra tail args for the mode.
run_core() {
  local in="$1" out="$2" cs="$3" scale="$4" binary="$5"; shift 5
  local angles=("$@")
  local cmd=("$IM" "$in" -resize "$WIDTH" -set "option:distort:viewport" '%wx%h+0+0'
    -colorspace "$cs" -separate null:
    \( -size 2x2 xc: \( +clone -negate \) +append \( +clone -negate \) -append \)
    -virtual-pixel tile -filter gaussian)
  local a
  for a in "${angles[@]}"; do
    cmd+=(\( +clone -distort SRT "$scale,$a" \) +swap)
  done
  cmd+=(+delete -compose Overlay -layers composite)
  if [[ "$binary" == 1 ]]; then cmd+=(-colors 2); fi
  cmd+=(-set colorspace "$cs" -combine)
  "${cmd[@]}" "$out"
}

run_one() {
  local in="$1" out="$2"
  case "$MODE" in
    truecmyk)
      run_core "$in" "$out" CMYK "$SCALE" 1 0 15 45 75
      ;;
    pink-old)
      # Old blog look: big dots, then gray -> 2 colors -> black/pink.
      local tmp
      tmp="$(mktemp --suffix=.png)"
      run_core "$in" "$tmp" CMYK "$SCALE" 0 0 15 45 75
      "$IM" "$tmp" -colorspace Gray -colors 2 +level-colors "black,$PINK" "$out"
      rm -f "$tmp"
      ;;
    pink-palette)
      local pal="$PALETTE" tmp
      if [[ -z "$pal" ]]; then pal="$(mktemp --suffix=.png)"; gen_palette "$pal"; fi
      tmp="$(mktemp --suffix=.png)"
      run_core "$in" "$tmp" CMYK 1 0 0 15 45 75
      "$IM" "$tmp" -remap "$pal" -colors "$COLORS" "$out"
      rm -f "$tmp"
      if [[ -z "$PALETTE" ]]; then rm -f "$pal"; fi
      ;;
    light-fix)
      # Author's fallback for overwhelmingly light images: no grid at all.
      local pal="$PALETTE"
      if [[ -z "$pal" ]]; then pal="$(mktemp --suffix=.png)"; gen_palette "$pal"; fi
      "$IM" "$in" -modulate 300,200,100 -negate -remap "$pal" "$out"
      if [[ -z "$PALETTE" ]]; then rm -f "$pal"; fi
      ;;
    rgb)
      # Same idea in RGB (3 channels). My extension of the method, not the author's.
      run_core "$in" "$out" RGB "$SCALE" 1 0 15 45
      ;;
    *)
      echo "halftone.sh: unknown mode '$MODE'" >&2; exit 1;;
  esac
  echo "halftone.sh: $MODE $in -> $out"
}

if [[ -n "$BATCH" ]]; then
  mkdir -p "$BATCH/big" "$BATCH/smol"
  shopt -s nullglob
  for f in "$BATCH"/*.webp "$BATCH"/*.png "$BATCH"/*.jpg "$BATCH"/*.jpeg "$BATCH"/*.gif; do
    base="$(basename "$f")"
    cp "$f" "$BATCH/big/"
    run_one "$f" "$BATCH/smol/$base"
  done
else
  [[ -n "$IN" && -n "$OUT" ]] || { echo "halftone.sh: need --in and --out (or --batch)" >&2; exit 1; }
  run_one "$IN" "$OUT"
fi
