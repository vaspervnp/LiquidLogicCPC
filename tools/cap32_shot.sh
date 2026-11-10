#!/bin/sh
# Τρέχει τη δισκέτα στο Caprice32 χωρίς παράθυρο, περιμένει να φορτώσει,
# βγάζει screenshot και κλείνει.
#   tools/cap32_shot.sh build/LiquidLogic.dsk build/screenshot.png
# Η αναμονή είναι πλήκτρα που «πληκτρολογούνται» μετά το run"disc:
# PAD=n για περισσότερη/λιγότερη, KEY=c για το πλήκτρο που «πληκτρολογείται»
# (z: δεν κάνει τίποτα στο παιχνίδι). MODEL=0 464, 1 664, 2 6128.
set -e
HERE=$(dirname "$(realpath "$0")")
DSK=$(realpath "$1")
OUT=$(realpath -m "${2:-build/screenshot.png}")
PAD=${PAD:-650}
SHOTS=$HOME/snap/caprice32/current/screenshots
mkdir -p "$(dirname "$OUT")"
KEY=${KEY:-z}
FILL=$(printf "$KEY%.0s" $(seq 1 "$PAD"))
CMD="run\"disc
$FILL\\(CAP32_SCRNSHOT)\\(CAP32_EXIT)"
MARK=$(mktemp)
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout 120 "$HERE/cap32.sh" \
  -O system.limit_speed=0 -O system.model=${MODEL:-2} -O system.ram_size=128 -O video.scr_fps=0 \
  -a "$CMD" "$DSK" > /dev/null 2>&1 || true
SHOT=$(find "$SHOTS" -name 'screenshot_*.png' -newer "$MARK" | sort | tail -1)
rm -f "$MARK"
[ -n "$SHOT" ] || { echo "δεν βγήκε screenshot"; exit 1; }
mv "$SHOT" "$OUT"
echo "$OUT"
