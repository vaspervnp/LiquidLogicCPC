"""Η οθόνη φόρτωσης του Liquid Logic (mode 0, 160 x 200).

    python3 assets/src/make_loading.py

Γράφει:
  assets/data/loading.bin       16384 bytes, η μνήμη της οθόνης στο #C000
  assets/data/loading_inks.txt  τα firmware inks των 16 pens (για το DISC.BAS)
  assets/preview/loading.png    προεπισκόπηση

Ίδια παλέτα, μπουκάλι και font με το παιχνίδι (make_gfx.py): μεγάλα
γράμματα με ρίγες υγρών, μπουκάλια, ένα που αδειάζει σε άλλο με πίδακα,
«LOADING».
"""

import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_gfx as g  # noqa: E402

W, H = 160, 200
LIQ = list(range(g.PEN_LIQUID, 16))


def make():
    scr = [[g.PEN_BG] * W for _ in range(H)]

    def put(x, y, p):
        if 0 <= x < W and 0 <= y < H:
            scr[y][x] = p

    def text(s, x, y, pen, sx=1, sy=2, rows=None):
        """Font 3x5: κάθε pixel sx x sy· rows = pen ανά γραμμή του γλύφου."""
        for ch in s:
            for gy, gr in enumerate(g.FONT[ch]):
                for gx, c in enumerate(gr):
                    if c == "#":
                        for yy in range(sy):
                            for xx in range(sx):
                                p = pen
                                if rows:
                                    p = rows[(gy * sy + yy) * len(rows) // (5 * sy)]
                                put(x + gx * sx + xx, y + gy * sy + yy, p)
            x += 4 * sx

    def width(s, sx=1):
        return len(s) * 4 * sx - sx

    # τίτλος: κάθε pixel του font 4 x 7, με οριζόντιες ρίγες υγρών
    stripes1 = [13, 4, 5, 6, 7, 8, 9]
    stripes2 = [10, 11, 12, 13, 4, 5, 6]
    text("LIQUID", (W - width("LIQUID", 4)) // 2, 6, 0, 4, 7, stripes1)
    text("LOGIC", (W - width("LOGIC", 4)) // 2, 48, 0, 4, 7, stripes2)

    # μπουκάλια: 6, με στρώσεις, ένα γερμένο που αδειάζει στο διπλανό του
    bottle = g.bottle_pixels()
    contents = [[4, 5, 6, 4], [5, 7, 7], [9, 8, 7], [10, 11, 12, 10],
                [6, 6, 6, 6], [14, 15, 5, 14]]
    by0 = 100
    xs = [8 + i * 25 for i in range(6)]
    pour_src, pour_dst = 2, 1
    for i, layers in enumerate(contents):
        bx, by = xs[i], by0
        tilt = 0
        if i == pour_src:
            by -= 14
            tilt = -1                       # προς τα αριστερά
        for y, line in enumerate(bottle):
            shift = tilt * round((g.BOTTLE_H - 1 - y) * 6 / (g.BOTTLE_H - 1))
            for x, p in enumerate(line):
                if p != g.PEN_BG:
                    put(bx + x + shift, by + y, p)
        lh = g.BODY_LINES // 4
        for k, c in enumerate(layers):
            for ln in range(lh):
                y = by + g.BODY_TOP + g.BODY_LINES - 1 - (k * lh + ln)
                shift = tilt * round((g.BOTTLE_H - 1 - (y - by)) * 6 / (g.BOTTLE_H - 1))
                for x in range(2, 14):
                    put(bx + x + shift, y, g.PEN_WHITE if x == 3 else c)
        if len(layers) == 4 and len(set(layers)) == 1:
            for cy, cr in enumerate(g.CORK):
                for cx, ch in enumerate(cr):
                    if ch != ".":
                        put(bx + 4 + cx, by + cy, g.PEN_CORK if ch == "c" else g.PEN_WHITE)

    # πίδακας από το γερμένο στο διπλανό: τόξο από σταγόνες
    sx, sy = xs[pour_src] + 2, by0 - 14
    tx, ty = xs[pour_dst] + 8, by0 + 3
    pen = contents[pour_src][-1]
    steps = 22
    for t in range(steps):
        f = t / (steps - 1)
        x = sx + (tx - sx) * f
        y = sy + (ty - sy) * f - 10 * math.sin(math.pi * f)
        if t % 2 == 0:
            put(int(x), int(y), pen)
            put(int(x), int(y) + 1, pen)

    # κείμενο
    s = "LOADING..."
    text(s, (W - width(s)) // 2, 178, g.PEN_WHITE)
    s = "AMSTRAD CPC 6128"
    text(s, (W - width(s)) // 2, 190, g.PEN_GLASS)
    return scr


def to_screen(scr):
    mem = bytearray(16384)
    for y in range(H):
        base = (y // 8) * 80 + (y % 8) * 0x800
        for xb in range(80):
            mem[base + xb] = g.pen_left(scr[y][2 * xb]) | g.pen_right(scr[y][2 * xb + 1])
    return mem


def main():
    scr = make()
    with open(os.path.join(g.DATA, "loading.bin"), "wb") as f:
        f.write(to_screen(scr))
    with open(os.path.join(g.DATA, "loading_inks.txt"), "w") as f:
        f.write(",".join(str(i) for i in g.PALETTE) + "\n")
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = g.FW_RGB[g.PALETTE[scr[y][x]]]
    os.makedirs(g.PREVIEW, exist_ok=True)
    img.resize((W * 4, H * 2), Image.NEAREST).save(os.path.join(g.PREVIEW, "loading.png"))
    print("assets/data/loading.bin, assets/data/loading_inks.txt, assets/preview/loading.png")


if __name__ == "__main__":
    main()
