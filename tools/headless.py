"""Αυτόματο test του Liquid Logic σε CPC 6128 χωρίς GUI.

Τρέχει τη δισκέτα στον headless emulator του ~/cpcemu (floooh/chips).

    python3 tools/headless.py shot   # build/screenshot.png μετά το φόρτωμα
    python3 tools/headless.py test   # παίζει με τα πλήκτρα και ελέγχει τη RAM
                                     # (μέσω build/liquid.sym):
      - λύνει τις πίστες 1 και 2 με τη λύση του solver (tools/levels.py),
        μετάγγιση-μετάγγιση, και ελέγχει στρώσεις, κινήσεις και τη νίκη
      - undo: μια μετάγγιση και U -> ίδιες στρώσεις, ένα undo λιγότερο
      - άκυρη μετάγγιση: τίποτα δεν αλλάζει
      - αδιέξοδο: μια κατάσταση χωρίς κινήσεις -> το μήνυμα στο HUD
      - R: η πίστα από την αρχή
    screenshots στο build/test_*.png, GIF μιας μετάγγισης στο build/pour.gif

CPCHEADLESS=/path για άλλον φάκελο του emulator. Βγαίνει με 1 αν κάποιος
έλεγχος αποτύχει.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.environ.get("CPCHEADLESS", os.path.expanduser("~/cpcemu")))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from cpc import CPC, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_UP  # noqa: E402
import levels  # noqa: E402

DSK = os.path.join(ROOT, "build", "LiquidLogic.dsk")
SYM = os.path.join(ROOT, "build", "liquid.sym")
OUT = os.path.join(ROOT, "build")

BOT_SIZE, B_CAP, B_CNT, B_RAISE, B_DONE, B_ROW, B_LAY = 16, 2, 3, 5, 6, 7, 8
ST_IDLE, ST_SEL, ST_POUR, ST_WIN = 0, 1, 2, 3
UNDO_MAX = 5


def symbols(path):
    sym = {}
    for line in open(path):
        parts = line.split()
        if len(parts) >= 2 and parts[1].startswith("#"):
            sym[parts[0].lower()] = int(parts[1][1:], 16)
    return sym


def boot():
    c = CPC()
    c.run_frames(150)
    c.insert_disc(DSK)
    c.type_text('RUN"DISC\n')
    c.run_frames(300)
    return c


def frame_image(c):
    """Το καρέ με σωστή αναλογία (κάθε γραμμή διπλή), χωρίς το border."""
    im = c.image()
    w, h = im.size
    return im.crop((64, 20, w - 64, h - 20)).resize((w - 128, (h - 40) * 2))


def shot(c, name):
    path = os.path.join(OUT, name)
    frame_image(c).save(path)
    print(path)


class Game:
    def __init__(self, c, sym):
        self.c, self.sym = c, sym
        self.fails = 0

    def peek(self, name, off=0):
        return self.c.peek(self.sym[name] + off)

    def bottles(self):
        n = self.peek("nbottles")
        raw = self.c.read_ram(self.sym["bottles"], n * BOT_SIZE)
        return [list(raw[i * BOT_SIZE + B_LAY:i * BOT_SIZE + B_LAY + raw[i * BOT_SIZE + B_CNT]])
                for i in range(n)]

    def check(self, ok, msg):
        if not ok:
            print("ΑΠΟΤΥΧΙΑ:", msg)
            self.fails += 1

    def key(self, k):
        self.c.tap_key(k)

    def goto(self, target):
        """Κέρσορας στο μπουκάλι target με βελάκια (όπως ο παίκτης)."""
        row = self.c.read_ram(self.sym["bottles"] + target * BOT_SIZE + B_ROW, 1)[0]
        cur_row = lambda: self.c.peek(self.sym["bottles"] + self.peek("cursor") * BOT_SIZE + B_ROW)  # noqa: E731
        for _ in range(4):
            if cur_row() == row:
                break
            self.key(KEY_DOWN if row > cur_row() else KEY_UP)
        for _ in range(16):
            if self.peek("cursor") == target:
                return
            self.key(KEY_RIGHT if self.peek("cursor") < target else KEY_LEFT)
        self.check(False, f"ο κέρσορας δεν έφτασε στο {target}")

    def pour(self, src, dst, gif=None):
        """Επιλογή src, μετά dst, και αναμονή ως το τέλος του πίδακα."""
        self.goto(src)
        self.key(KEY_SPACE)
        self.check(self.peek("state") == ST_SEL, f"το {src} δεν σηκώθηκε")
        self.goto(dst)
        self.c.tap_key(KEY_SPACE, hold_frames=1, gap_frames=0)
        for _ in range(400):
            self.c.run_frames(1)
            if gif is not None:
                gif.append(frame_image(self.c))
            if self.peek("state") != ST_POUR:
                break
        self.c.run_frames(2)

    def play_solution(self, lv, name):
        state = [list(b) for b in lv["bottles"]]
        self.check(self.bottles() == state, f"{name}: αρχικές στρώσεις")
        for k, (i, j, n) in enumerate(lv["solution"]):
            self.pour(i, j)
            state = [list(b) for b in levels.apply(state, (i, j, n))]
            got = self.bottles()
            if got != state:
                self.check(False, f"{name}, κίνηση {k + 1} ({i}->{j}): {got} αντί {state}")
                return
        self.check(self.peek("moves") == lv["par"], f"{name}: κινήσεις {self.peek('moves')}, par {lv['par']}")
        self.check(self.peek("state") == ST_WIN, f"{name}: δεν δηλώθηκε νίκη")
        self.check(self.peek("p_alive") == 0, f"{name}: ζωντανά σωματίδια στο τέλος")


def test():
    sym = symbols(SYM)
    levs = levels.levels()
    c = boot()
    g = Game(c, sym)
    shot(c, "test_0_level1.png")

    # 1. Πίστα 1 ως το τέλος
    g.check(g.peek("level") == 0, "δεν ξεκίνησε από την πίστα 1")
    g.play_solution(levs[0], "πίστα 1")
    shot(c, "test_1_clear.png")
    g.key(KEY_SPACE)
    c.run_frames(5)
    g.check(g.peek("level") == 1, "το SPACE μετά τη νίκη δεν πήγε στην πίστα 2")

    # 2. Πίστα 2: undo, άκυρη, restart, λύση
    lv = levs[1]
    start = g.bottles()
    i, j, n = lv["solution"][0]
    gif = []
    g.pour(i, j, gif)
    gif[0].save(os.path.join(OUT, "pour.gif"), save_all=True, append_images=gif[1:], duration=20, loop=0)
    g.check(g.bottles() != start and g.peek("moves") == 1, "η 1η μετάγγιση της πίστας 2")
    g.key(ord("U"))
    c.run_frames(3)
    g.check(g.bottles() == start, "undo: οι στρώσεις δεν γύρισαν")
    g.check(g.peek("undo_left") == UNDO_MAX - 1, "undo: ο μετρητής undo")
    g.check(g.peek("moves") == 0, "undo: οι κινήσεις")
    g.key(ord("U"))                     # τίποτα να αναιρεθεί
    g.check(g.peek("undo_left") == UNDO_MAX - 1, "undo χωρίς κινήσεις χάλασε τον μετρητή")

    # άκυρη: μια κορυφή πάνω σε άλλο χρώμα
    b = g.bottles()
    bad = next(((a, d) for a in range(len(b)) for d in range(len(b))
                if a != d and b[a] and b[d] and len(b[d]) < lv["cap"] and b[a][-1] != b[d][-1]), None)
    if bad:
        g.pour(*bad)
        g.check(g.bottles() == b and g.peek("state") == ST_IDLE, f"η άκυρη {bad} άλλαξε κάτι")

    # R: από την αρχή (μετά από μία κίνηση)
    g.pour(i, j)
    g.key(ord("R"))
    c.run_frames(3)
    g.check(g.bottles() == start and g.peek("moves") == 0 and g.peek("undo_left") == UNDO_MAX,
            "R: η πίστα δεν ξεκίνησε από την αρχή")
    g.play_solution(lv, "πίστα 2")
    shot(c, "test_2_clear.png")

    # 3. Αδιέξοδο: πίστα 3 με γραμμένες στρώσεις χωρίς κινήσεις εκτός από μία
    g.key(KEY_SPACE)
    c.run_frames(5)
    n = g.peek("nbottles")
    cap = lv["cap"]
    # όλα γεμάτα με εναλλασσόμενα χρώματα, ένα με 3 στρώσεις και κορυφή διαφορετική
    # από όλες, ένα άδειο: η μόνη κίνηση είναι προς το άδειο, μετά αδιέξοδο.
    pens = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
    stuck = []
    for k in range(n):
        p, q = pens[k % len(pens)], pens[(k + 1) % len(pens)]
        stuck.append([p, q, p, q][:cap])
    stuck[-1] = []
    stuck[0] = [15, 15, 14]
    for k, layers in enumerate(stuck):
        base = sym["bottles"] + k * BOT_SIZE
        c.write_ram(base + B_CNT, bytes([len(layers)]))
        c.write_ram(base + B_LAY, bytes(layers + [0] * (6 - len(layers))))
    g.pour(0, n - 1)
    shot(c, "test_3_stuck.png")
    hud = c.read_ram(0xC000 + 80 * 0 + 0x800 * 3, 80)   # γραμμή 3: πρώτη του κειμένου
    g.check(g.peek("state") == ST_IDLE, "αδιέξοδο: κατάσταση")
    g.check(not any(hud[:12]) and not any(hud[68:]), "αδιέξοδο: το μήνυμα δεν είναι κεντραρισμένο")
    g.check(any(hud[20:60]), "αδιέξοδο: δεν φάνηκε μήνυμα")

    print("OK" if not g.fails else f"{g.fails} αποτυχίες")
    return 1 if g.fails else 0


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if mode == "shot":
        c = boot()
        shot(c, "screenshot.png")
        return 0
    return test()


if __name__ == "__main__":
    sys.exit(main())
