"""Παράγει τα γραφικά και τους πίνακες φυσικής του Liquid Logic.

    python3 assets/src/make_gfx.py

Γράφει:
  assets/data/gfx.asm       παλέτα, πίνακες pen, μπουκάλι, κέρσορας, φελλός, font
  assets/data/physics.asm   πίνακες βαλλιστικής για τα particles
  assets/preview/*.png      προεπισκόπηση (x4, με την αναλογία του mode 0)

Mode 0: 2 pixels/byte. Αριστερό pixel: bits 7,3,5,1 = bit 0,1,2,3 του pen,
δεξί: bits 6,2,4,0.
"""

import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "assets", "data")
PREVIEW = os.path.join(ROOT, "assets", "preview")

# Firmware ink -> hardware code του gate array (με το bit 6 ήδη μέσα).
FW2HW = [0x54, 0x44, 0x55, 0x5C, 0x58, 0x5D, 0x4C, 0x45, 0x4D, 0x56, 0x46,
         0x57, 0x5E, 0x40, 0x5F, 0x4E, 0x47, 0x4F, 0x52, 0x42, 0x53, 0x5A,
         0x59, 0x5B, 0x4A, 0x43, 0x4B]

# Firmware ink -> RGB (για την προεπισκόπηση).
FW_RGB = []
for i in range(27):
    lv = (0, 128, 255)
    FW_RGB.append((lv[(i // 3) % 3], lv[i // 9], lv[i % 3]))

# Pens (plan.md, §4): 0 φόντο, 1 γυαλί, 2 λάμψη/κείμενο, 3 κρυμμένη στρώση,
# 4-15 τα 12 υγρά.
PALETTE = [0, 13, 26, 1,
           6, 15, 24, 18, 9, 20, 2, 7, 8, 16, 3, 12]
PEN_BG, PEN_GLASS, PEN_WHITE, PEN_HIDDEN = 0, 1, 2, 3
PEN_LIQUID = 4
PEN_CORK = 15           # καφέ-λαδί

LEFT_BITS = (7, 3, 5, 1)
RIGHT_BITS = (6, 2, 4, 0)


def pen_left(p):
    return sum(1 << LEFT_BITS[b] for b in range(4) if p >> b & 1)


def pen_right(p):
    return sum(1 << RIGHT_BITS[b] for b in range(4) if p >> b & 1)


def encode(rows):
    """Γραμμές από pens (ζυγό πλάτος) -> bytes mode 0."""
    out = []
    for row in rows:
        assert len(row) % 2 == 0
        out.append([pen_left(row[i]) | pen_right(row[i + 1]) for i in range(0, len(row), 2)])
    return out


# ---------------------------------------------------------------------------
# Μπουκάλι: 16 pixels x 70 γραμμές. Το σώμα (γρ. 6-65) έχει εσωτερικό στα
# pixels 2-13 (bytes 1-6), με τη λάμψη του γυαλιού στο pixel 3. Οι γραμμές
# του υγρού τις σχεδιάζει ο κώδικας (screen.asm: liquid_row).
#   . φόντο   # γυαλί   o λάμψη (λευκό)   - λάμψη μέσα στο άδειο (γυαλί)
BOTTLE_TOP = [
    "...##########...",     # 0 χείλος
    "...#o.......#...",     # 1
    "....#o.....#....",     # 2 λαιμός
    "....#-.....#....",     # 3
    "...#-.......#...",     # 4 ώμος
    "..#-.........#..",     # 5
]
BOTTLE_BODY = ".#.-..........#."  # 6-65
BOTTLE_BOTTOM = [
    ".#............#.",     # 66
    ".##..........##.",     # 67
    "..############..",     # 68
    "................",     # 69
]
BOTTLE_W, BOTTLE_H = 16, 70
BODY_TOP, BODY_LINES = 6, 60

CHARS = {".": PEN_BG, "#": PEN_GLASS, "o": PEN_WHITE, "-": PEN_GLASS}


def bottle_pixels():
    rows = BOTTLE_TOP + [BOTTLE_BODY] * BODY_LINES + BOTTLE_BOTTOM
    assert len(rows) == BOTTLE_H and all(len(r) == BOTTLE_W for r in rows)
    # Η άκρη του σώματος: ο εξωτερικός τοίχος έχει και δεύτερο pixel σκιάς
    out = []
    for r in rows:
        out.append([CHARS[c] for c in r])
    return out


# Κέρσορας: βέλος προς τα πάνω, 8 x 6, κάτω από το μπουκάλι.
CURSOR = [
    "...oo...",
    "..oooo..",
    ".oooooo.",
    "...oo...",
    "...oo...",
    "...oo...",
]

# Φελλός ολοκληρωμένου μπουκαλιού: μπαίνει στις γρ. 0-4, bytes 2-5.
CORK = [
    "..cccc..",
    ".ccccco.",
    ".ccccco.",
    "..cccc..",
    "..cccc..",
]

# «?» της κρυμμένης στρώσης (pen 2 πάνω σε pen 3), 4 x 5, μπαίνει στο κέντρο.
HIDDEN_Q = [
    ".oo.",
    "o..o",
    "..o.",
    "....",
    "..o.",
]

# Λουκέτο (μπουκάλι κλειδωμένο με χρώμα), 8 x 11, αδιαφανές: o λευκό,
# c το χρώμα του λουκέτου (ο κώδικας το βάφει), . μαύρο.
LOCK = [
    "..oooo..",
    ".o....o.",
    ".o....o.",
    ".o....o.",
    "oooooooo",
    "occcccco",
    "occ..cco",
    "occ..cco",
    "occcccco",
    "occcccco",
    "oooooooo",
]

# Βολβός του σταγονόμετρου, στη θέση του φελλού (γρ. 0-4, bytes 2-5).
BULB = [
    "..oooo..",
    ".oooooo.",
    ".oooooo.",
    "..oooo..",
    "...oo...",
]

# Font 3x5 (στήλη 4 = κενό), κάθε γραμμή του διπλασιάζεται -> 4 x 10.
FONT = {
    " ": ["...", "...", "...", "...", "..."],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", ".#.", "#..", "###"],
    ":": ["...", ".#.", "...", ".#.", "..."],
    "-": ["...", "...", "###", "...", "..."],
    "/": ["..#", "..#", ".#.", "#..", "#.."],
    "!": [".#.", ".#.", ".#.", "...", ".#."],
    "+": ["...", ".#.", "###", ".#.", "..."],
    "*": [".#.", "###", ".#.", "#.#", "..."],
    "?": ["##.", "..#", ".#.", "...", ".#."],
    ".": ["...", "...", "...", "...", ".#."],
}
FONT_ORDER = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:-/!?.+*"


def art(rows, mapping):
    return [[mapping[c] for c in r] for r in rows]


def db_lines(label, rows, comment=None):
    out = []
    if comment:
        out.append(f"; {comment}")
    out.append(f"{label}:")
    for r in rows:
        out.append("        db " + ",".join(f"#{b:02X}" for b in r))
    return out


def make_gfx():
    lines = [
        "; gfx.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_gfx.py, μην το αλλάζεις με το χέρι",
        "",
        f"BOTTLE_W        equ {BOTTLE_W // 2}           ; bytes",
        f"BOTTLE_H        equ {BOTTLE_H}",
        f"BODY_TOP        equ {BODY_TOP}            ; πρώτη γραμμή του σώματος",
        f"BODY_LINES      equ {BODY_LINES}",
        f"BODY_BOTTOM     equ {BODY_TOP + BODY_LINES - 1}           ; τελευταία γραμμή υγρού",
        f"PEN_BG          equ {PEN_BG}",
        f"PEN_GLASS       equ {PEN_GLASS}",
        f"PEN_WHITE       equ {PEN_WHITE}",
        f"PEN_HIDDEN      equ {PEN_HIDDEN}",
        f"PEN_LIQUID      equ {PEN_LIQUID}",
        f"CURSOR_W        equ {len(CURSOR[0]) // 2}",
        f"CURSOR_H        equ {len(CURSOR)}",
        f"CORK_W          equ {len(CORK[0]) // 2}",
        f"CORK_H          equ {len(CORK)}",
        f"LOCK_W          equ {len(LOCK[0]) // 2}",
        f"LOCK_H          equ {len(LOCK)}",
        f"PL_WHITE        equ #{pen_left(PEN_WHITE):02X}",
        f"PB_WHITE        equ #{pen_left(PEN_WHITE) | pen_right(PEN_WHITE):02X}",
        f"FONT_CHARS      equ {len(FONT_ORDER)}",
        f"PR_GLASS        equ #{pen_right(PEN_GLASS):02X}         ; pen_right[γυαλί]: λάμψη στο άδειο",
        f"PL_GLASS        equ #{pen_left(PEN_GLASS):02X}",
        f"PR_WHITE        equ #{pen_right(PEN_WHITE):02X}         ; pen_right[λευκό]: λάμψη στο υγρό",
        "",
        "; hardware codes των 16 pens + border",
        "palette_hw:",
        "        db " + ",".join(f"#{FW2HW[i]:02X}" for i in PALETTE),
        "",
        "; byte mode 0 για pen στο αριστερό / δεξί pixel",
        "pen_left:",
        "        db " + ",".join(f"#{pen_left(p):02X}" for p in range(16)),
        "pen_right:",
        "        db " + ",".join(f"#{pen_right(p):02X}" for p in range(16)),
        "pen_both:",
        "        db " + ",".join(f"#{pen_left(p) | pen_right(p):02X}" for p in range(16)),
        "",
    ]
    lines += db_lines("bottle_gfx", encode(bottle_pixels()), "μπουκάλι, 8 bytes x 70 γραμμές")
    lines.append("")
    m = {".": PEN_BG, "o": PEN_WHITE, "c": PEN_CORK}
    lines += db_lines("cursor_gfx", encode(art(CURSOR, m)), "κέρσορας 4 x 6")
    lines.append("")
    lines += db_lines("cork_gfx", encode(art(CORK, m)), "φελλός 4 x 5")
    lines.append("")
    q = encode(art(HIDDEN_Q, {".": PEN_HIDDEN, "o": PEN_WHITE}))
    lines += db_lines("hidden_q_gfx", q, "«?» κρυμμένης στρώσης 2 x 5")
    lines.append("")
    lines += db_lines("bulb_gfx", encode(art(BULB, m)), "βολβός σταγονόμετρου 4 x 5")
    lines.append("")
    # λουκέτο: μάσκα λευκού (έτοιμη) και μάσκα χρώματος, ανά byte εναλλάξ
    white = encode(art(LOCK, {".": 0, "o": PEN_WHITE, "c": 0}))
    fill = encode(art(LOCK, {".": 0, "o": 0, "c": 15}))
    lines += db_lines("lock_gfx", [[x for pair in zip(w, f) for x in pair] for w, f in zip(white, fill)],
                      "λουκέτο 4 x 11: ανά byte (λευκό, μάσκα χρώματος)")
    lines.append("")
    # Font: μάσκες (pen 15 = όλα τα bits του pixel), 2 bytes x 5 γραμμές.
    lines.append("; font 3x5: ανά χαρακτήρα 5 γραμμές x 2 bytes μάσκα (AND με pen_both)")
    lines.append(f"; σειρά: \"{FONT_ORDER}\"")
    lines.append("font_gfx:")
    for ch in FONT_ORDER:
        g = [[15 if c == "#" else 0 for c in r + "."] for r in FONT[ch]]
        b = encode(g)
        lines.append("        db " + ",".join(f"#{x:02X}" for r in b for x in r) + f"  ; {ch!r}")
    lines.append("")
    # ASCII -> δείκτης font (32..95), 255 = άγνωστος -> κενό
    tab = []
    for c in range(32, 96):
        ch = chr(c)
        tab.append(FONT_ORDER.index(ch) if ch in FONT_ORDER else 0)
    lines.append("; ASCII 32-95 -> χαρακτήρας του font")
    lines.append("font_map:")
    for i in range(0, 64, 16):
        lines.append("        db " + ",".join(str(x) for x in tab[i:i + 16]))
    return lines


# ---------------------------------------------------------------------------
# Φυσική (plan.md §5). Βαρύτητα G σε 8.8 (γραμμές/καρέ²). Για ύψος h
# γραμμών: ταχύτητα που φτάνει στο h (vy0) και χρόνος για να διανυθεί
# (καρέ, στρογγυλεμένος). Η ελεύθερη πτώση h γραμμών κρατάει τον ίδιο χρόνο.
G = 96              # 0.375
H_MAX = 256
T_MAX = 128


def make_physics():
    g = G / 256
    vy0, tt = [], []
    for h in range(H_MAX):
        v = math.sqrt(2 * g * h)
        vy0.append(round(v * 256))
        tt.append(max(1, round(v / g)) if h else 1)
    recip = [0xFFFF] + [min(0xFFFF, round(65536 / t)) for t in range(1, T_MAX)]
    lines = [
        "; physics.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_gfx.py, μην το αλλάζεις με το χέρι",
        "",
        f"GRAVITY         equ {G}            ; 8.8, γραμμές/καρέ²",
        "",
        "; ταχύτητα (8.8, θετική) για άνοδο/πτώση h γραμμών, h = 0..255",
        "phys_v:",
    ]
    for i in range(0, H_MAX, 16):
        lines.append("        dw " + ",".join(f"#{x:04X}" for x in vy0[i:i + 16]))
    lines.append("; χρόνος (καρέ) για άνοδο/πτώση h γραμμών")
    lines.append("phys_t:")
    for i in range(0, H_MAX, 16):
        lines.append("        db " + ",".join(str(x) for x in tt[i:i + 16]))
    lines.append("; 65536/T, T = 0..127")
    lines.append("phys_recip:")
    for i in range(0, T_MAX, 16):
        lines.append("        dw " + ",".join(f"#{x:04X}" for x in recip[i:i + 16]))
    return lines


# ---------------------------------------------------------------------------
def preview():
    """Mock-up της οθόνης του demo (x2 οριζόντια για το mode 0, x2 συνολικά)."""
    W, H = 160, 200
    img = Image.new("RGB", (W, H), FW_RGB[PALETTE[0]])
    px = img.load()
    bottle = bottle_pixels()
    contents = [[4, 5, 6, 4], [7, 8, 5, 9], [10, 11, 12, 13], [6, 14, 15, 7], [3, 3, 3, 8],
                [9, 9, 9, 9], [12, 13], [], []]

    def put(x, y, p):
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = FW_RGB[PALETTE[p]]

    rows = [contents[:5], contents[5:]]
    tops = [28, 118]
    for r, row in enumerate(rows):
        n = len(row)
        x0 = (80 - (n * 11 - 3)) // 2
        for j, layers in enumerate(row):
            bx, by = (x0 + j * 11) * 2, tops[r] - (8 if (r, j) == (0, 1) else 0)
            for y, line in enumerate(bottle):
                for x, p in enumerate(line):
                    put(bx + x, by + y, p)
            for k, c in enumerate(layers):
                for ln in range(15):
                    y = by + BODY_TOP + BODY_LINES - 1 - (k * 15 + ln)
                    for x in range(2, 14):
                        put(bx + x, y, PEN_WHITE if x == 3 else c)
                if c == PEN_HIDDEN:
                    for qy, qr in enumerate(HIDDEN_Q):
                        for qx, ch in enumerate(qr):
                            if ch == "o":
                                put(bx + 6 + qx, by + BODY_TOP + BODY_LINES - 1 - k * 15 - 12 + qy, PEN_WHITE)
            if len(layers) == 4 and len(set(layers)) == 1:
                for cy, cr in enumerate(CORK):
                    for cx, ch in enumerate(cr):
                        if ch != ".":
                            put(bx + 4 + cx, by + cy, PEN_CORK if ch == "c" else PEN_WHITE)
    # κέρσορας κάτω από το 2ο μπουκάλι
    x0 = (80 - (5 * 11 - 3)) // 2
    for cy, cr in enumerate(CURSOR):
        for cx, ch in enumerate(cr):
            if ch == "o":
                put((x0 + 11) * 2 + 4 + cx, 28 + 72 + cy, PEN_WHITE)
    # τόξο από particles από το 2ο στο 4ο μπουκάλι
    sx, sy = (x0 + 11) * 2 + 8, 20 - 2
    tx, ty = (x0 + 33) * 2 + 8, 28 + 4
    apex = min(sy, ty) - 12
    g = G / 256
    t1 = math.sqrt(2 * (sy - apex) / g)
    t2 = math.sqrt(2 * (ty - apex) / g)
    T = t1 + t2
    vx, vy = (tx - sx) / T, -math.sqrt(2 * g * (sy - apex))
    x, y = sx, sy
    for t in range(int(T)):
        if t % 2 == 0:
            put(int(x), int(y) & ~1, 7)
            put(int(x), (int(y) & ~1) + 1, 7)
        x += vx
        y += vy
        vy += g
    # κείμενο HUD
    s, cx = "LIQUID LOGIC", 4
    for ch in s:
        for gy, gr in enumerate(FONT[ch]):
            for gx, c in enumerate(gr):
                if c == "#":
                    put(cx + gx, 3 + gy * 2, PEN_WHITE)
                    put(cx + gx, 4 + gy * 2, PEN_WHITE)
        cx += 4
    os.makedirs(PREVIEW, exist_ok=True)
    img.resize((W * 4, H * 2), Image.NEAREST).save(os.path.join(PREVIEW, "mockup.png"))
    # παλέτα
    pal = Image.new("RGB", (16 * 32, 32))
    for i, fw in enumerate(PALETTE):
        pal.paste(FW_RGB[fw], (i * 32, 0, i * 32 + 32, 32))
    pal.save(os.path.join(PREVIEW, "palette.png"))


def main():
    os.makedirs(DATA, exist_ok=True)
    with open(os.path.join(DATA, "gfx.asm"), "w") as f:
        f.write("\n".join(make_gfx()) + "\n")
    with open(os.path.join(DATA, "physics.asm"), "w") as f:
        f.write("\n".join(make_physics()) + "\n")
    preview()
    print("assets/data/gfx.asm, assets/data/physics.asm, assets/preview/*.png")


if __name__ == "__main__":
    main()
