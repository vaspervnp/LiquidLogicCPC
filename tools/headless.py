"""Αυτόματο test του Liquid Logic σε CPC 6128 χωρίς GUI.

Τρέχει τη δισκέτα στον headless emulator του ~/cpcemu (floooh/chips).

    python3 tools/headless.py shot   # build/screenshot.png μετά το φόρτωμα
    python3 tools/headless.py test   # παίζει με τα πλήκτρα και ελέγχει τη RAM
                                     # (μέσω build/liquid.sym):
      - λύνει ΟΛΕΣ τις πίστες με τη λύση του solver (tools/levels.py),
        μετάγγιση-μετάγγιση, και ελέγχει στρώσεις, κινήσεις και τη νίκη
      - ανά ειδικό τύπο: πάγος, λουκέτο, όριο κινήσεων, σταγονόμετρο,
        κουρτίνα, κρυμμένες, χρονόμετρο, έξτρα μπουκάλι, undo (στιγμιότυπα)
      - άκυρη μετάγγιση, R, αδιέξοδο
    screenshots στο build/test_*.png, GIF μιας μετάγγισης στο build/pour.gif

    python3 tools/headless.py test 7    # μόνο η πίστα 7 (και οι έλεγχοί της)

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

BOT_SIZE = 24
B_CAP, B_CNT, B_RAISE, B_DONE, B_ROW, B_LAY, B_FLAGS, B_FREEZE, B_LOCK = 2, 3, 5, 6, 7, 8, 14, 15, 16
BF_CURTAIN = 16
ST_IDLE, ST_SEL, ST_POUR, ST_WIN, ST_FAIL = 0, 1, 2, 3, 4
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
    return path


class Game:
    def __init__(self, c, sym):
        self.c, self.sym = c, sym
        self.fails = 0

    def peek(self, name, off=0):
        return self.c.peek(self.sym[name] + off)

    def bot(self, i, field):
        return self.c.peek(self.sym["bottles"] + i * BOT_SIZE + field)

    def raw_layers(self):
        n = self.peek("nbottles")
        raw = self.c.read_ram(self.sym["bottles"], n * BOT_SIZE)
        return [list(raw[i * BOT_SIZE + B_LAY:i * BOT_SIZE + B_LAY + raw[i * BOT_SIZE + B_CNT]])
                for i in range(n)]

    def layers(self):
        return [[x & 0x7F for x in b] for b in self.raw_layers()]

    def check(self, ok, msg):
        if not ok:
            print("ΑΠΟΤΥΧΙΑ:", msg)
            self.fails += 1
        return ok

    def key(self, k):
        self.c.tap_key(k)

    def goto(self, target):
        """Κέρσορας στο μπουκάλι target με βελάκια (όπως ο παίκτης)."""
        row = self.bot(target, B_ROW)
        for _ in range(4):
            cur = self.bot(self.peek("cursor"), B_ROW)
            if cur == row:
                break
            self.key(KEY_DOWN if row > cur else KEY_UP)
        for _ in range(16):
            if self.peek("cursor") == target:
                return
            self.key(KEY_RIGHT if self.peek("cursor") < target else KEY_LEFT)
        self.check(False, f"ο κέρσορας δεν έφτασε στο {target}")

    def select(self, i):
        self.goto(i)
        self.key(KEY_SPACE)
        return self.peek("state") == ST_SEL

    def pour(self, src, dst, gif=None):
        """Επιλογή src, μετά dst, και αναμονή ως το τέλος του πίδακα."""
        if not self.select(src):
            return False
        self.goto(dst)
        self.c.tap_key(KEY_SPACE, hold_frames=1, gap_frames=0)
        for _ in range(10):             # το πάτημα διαβάζεται στο επόμενο VSYNC
            if self.peek("state") != ST_SEL:
                break
            self.c.run_frames(1)
        for _ in range(400):
            if self.peek("state") != ST_POUR:
                break
            self.c.run_frames(1)
            if gif is not None:
                gif.append(frame_image(self.c))
        self.c.run_frames(2)
        return True

    def load_level(self, index):
        """Πίστα index (από 0): γράφεται στο level και R."""
        self.c.write_ram(self.sym["level"], bytes([index]))
        self.key(ord("R"))
        self.c.run_frames(25)           # όλη η οθόνη ξανασχεδιάζεται
        self.check(self.peek("level") == index and self.peek("moves") == 0, f"φόρτωμα πίστας {index + 1}")

    def play(self, lv, name, upto=None):
        state = levels.state_of(lv)
        masked = lambda st: [[x & 0x7F for x in b[-1]] for b in st]  # noqa: E731
        if not self.check(self.layers() == masked(state), f"{name}: αρχικές στρώσεις"):
            return False
        sol = lv["solution"] if upto is None else lv["solution"][:upto]
        for k, (i, j, n) in enumerate(sol):
            if not self.check(self.pour(i, j), f"{name}, κίνηση {k + 1}: το {i} δεν επιλέγεται"):
                return False
            state = levels.apply(state, (i, j, n))
            got = self.layers()
            if not self.check(got == masked(state) and self.raw_layers() == [list(b[-1]) for b in state],
                              f"{name}, κίνηση {k + 1} ({i}->{j}): {got}"):
                return False
        if upto is None:
            self.check(self.peek("moves") == lv["par"], f"{name}: κινήσεις {self.peek('moves')}, par {lv['par']}")
            self.check(self.peek("state") == ST_WIN, f"{name}: δεν δηλώθηκε νίκη")
            self.check(self.peek("p_alive") == 0, f"{name}: ζωντανά σωματίδια στο τέλος")
        return True


def first(lv, pred):
    return next((i for i, b in enumerate(lv["bottles"]) if pred(b)), None)


def special_checks(g, lv, idx):
    """Έλεγχοι ειδικών τύπων πριν από τη λύση. Αφήνει την πίστα από την αρχή."""
    c, name = g.c, f"πίστα {idx + 1}"
    sol = lv["solution"]
    # πάγος: δεν επιλέγεται· μετά από K κινήσεις ξεπαγώνει· το undo τον επαναφέρει
    fz = first(lv, lambda b: b["freeze"])
    if fz is not None:
        k = lv["bottles"][fz]["freeze"]
        g.check(not g.select(fz), f"{name}: το παγωμένο {fz} επιλέχτηκε")
        if g.peek("state") == ST_SEL:
            g.key(KEY_SPACE)
        g.play(lv, name, upto=1)
        g.check(g.bot(fz, B_FREEZE) == k - 1, f"{name}: ο πάγος δεν μέτρησε την κίνηση")
        g.key(ord("U"))
        c.run_frames(3)
        g.check(g.bot(fz, B_FREEZE) == k and g.peek("moves") == 0, f"{name}: undo δεν επανέφερε τον πάγο")
        g.load_level(idx)
    # λουκέτο: δεν επιλέγεται ως το χρώμα του
    lk = first(lv, lambda b: b["lock"])
    if lk is not None:
        g.check(not g.select(lk), f"{name}: το κλειδωμένο {lk} επιλέχτηκε")
        if g.peek("state") == ST_SEL:
            g.key(KEY_SPACE)
    # κουρτίνα: φεύγει στην πρώτη μετάγγιση που το αφορά
    ct = first(lv, lambda b: b["curtain"])
    if ct is not None:
        g.check(g.bot(ct, B_FLAGS) & BF_CURTAIN, f"{name}: χωρίς κουρτίνα στο {ct}")
        k = next(k for k, (i, j, n) in enumerate(sol) if ct in (i, j))
        g.play(lv, name, upto=k + 1)
        g.check(not g.bot(ct, B_FLAGS) & BF_CURTAIN, f"{name}: η κουρτίνα του {ct} έμεινε")
        g.load_level(idx)
    # κρυμμένες: η νέα κορυφή της πηγής αποκαλύπτεται
    if lv["flags"] & levels.LF_HIDDEN:
        i, j, n = sol[0]
        g.play(lv, name, upto=1)
        raw = g.raw_layers()[i]
        g.check(not raw or not raw[-1] & 0x80, f"{name}: η κορυφή του {i} έμεινε κρυμμένη")
        g.check(any(x & 0x80 for b in g.raw_layers() for x in b), f"{name}: καμία κρυμμένη στρώση")
        g.load_level(idx)
    # όριο κινήσεων: στο όριο καμία μετάγγιση
    if lv["moves"]:
        g.check(g.peek("level_moves") == lv["moves"], f"{name}: όριο κινήσεων")
        c.write_ram(g.sym["moves"], bytes([lv["moves"]]))
        before = g.layers()
        i, j, n = sol[0]
        g.pour(i, j)
        g.check(g.layers() == before and g.peek("state") == ST_IDLE, f"{name}: μετάγγιση πέρα από το όριο")
        g.load_level(idx)
    # χρονόμετρο: στο 0 -> ST_FAIL
    if lv["timer"]:
        g.check(g.c.read_ram(g.sym["time_left"], 2) == bytes([(lv["timer"] * 4) & 255, (lv["timer"] * 4) >> 8]),
                f"{name}: αρχικός χρόνος")
        c.write_ram(g.sym["time_left"], bytes([2, 0]))
        c.run_frames(130)
        g.check(g.peek("state") == ST_FAIL, f"{name}: δεν έληξε ο χρόνος")
        shot(c, "test_timeup.png")
        g.load_level(idx)
    # έξτρα μπουκάλι: E -> ένα παραπάνω, μία φορά
    if lv["flags"] & levels.LF_EXTRA:
        n = g.peek("nbottles")
        g.key(ord("E"))
        c.run_frames(3)
        g.check(g.peek("nbottles") == n + 1, f"{name}: το E δεν πρόσθεσε μπουκάλι")
        g.key(ord("E"))
        c.run_frames(3)
        g.check(g.peek("nbottles") == n + 1, f"{name}: το E δούλεψε δεύτερη φορά")
        shot(c, "test_extra.png")
        g.load_level(idx)
        g.check(g.peek("nbottles") == n, f"{name}: το R δεν έβγαλε το έξτρα μπουκάλι")


def test(only=None):
    sym = symbols(SYM)
    levs = levels.levels()
    c = boot()
    g = Game(c, sym)
    shot(c, "test_0_level1.png")

    # undo, άκυρη, R στην πίστα 2
    if only is None:
        g.load_level(1)
        lv = levs[1]
        start = g.layers()
        i, j, n = lv["solution"][0]
        gif = []
        g.pour(i, j, gif)
        gif[0].save(os.path.join(OUT, "pour.gif"), save_all=True, append_images=gif[1:], duration=20, loop=0)
        g.key(ord("U"))
        c.run_frames(3)
        g.check(g.layers() == start and g.peek("undo_left") == UNDO_MAX - 1 and g.peek("moves") == 0, "undo")
        b = g.layers()
        bad = next(((a, d) for a in range(len(b)) for d in range(len(b))
                    if a != d and b[a] and b[d] and len(b[d]) < lv["cap"] and b[a][-1] != b[d][-1]), None)
        if bad:
            g.pour(*bad)
            g.check(g.layers() == b and g.peek("state") == ST_IDLE, f"η άκυρη {bad} άλλαξε κάτι")
        g.pour(i, j)
        g.key(ord("R"))
        c.run_frames(3)
        g.check(g.layers() == start and g.peek("moves") == 0 and g.peek("undo_left") == UNDO_MAX, "R")

    todo = range(len(levs)) if only is None else [only]
    for idx in todo:
        lv = levs[idx]
        g.load_level(idx)
        shot(c, f"test_lv{idx + 1:02d}.png")
        special_checks(g, lv, idx)
        before = g.fails
        g.play(lv, f"πίστα {idx + 1}")
        print(f"πίστα {idx + 1:2d}: {'OK' if g.fails == before else 'ΑΠΟΤΥΧΙΑ'}  (par {lv['par']})")

    # αδιέξοδο: πίστα 3 με γραμμένες στρώσεις, μία κίνηση και μετά τίποτα
    if only is None:
        g.load_level(2)
        n = g.peek("nbottles")
        pens = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
        stuck = [[pens[k % 10], pens[(k + 1) % 10]] * 2 for k in range(n)]
        stuck[-1] = []
        stuck[0] = [15, 15, 14]
        for k, layers in enumerate(stuck):
            base = sym["bottles"] + k * BOT_SIZE
            c.write_ram(base + B_CNT, bytes([len(layers)]))
            c.write_ram(base + B_LAY, bytes(layers + [0] * (6 - len(layers))))
        g.pour(0, n - 1)
        shot(c, "test_stuck.png")
        hud = c.read_ram(0xC000 + 0x800 * 3, 80)
        g.check(g.peek("state") == ST_IDLE and any(hud[20:60]) and not any(hud[:12]), "αδιέξοδο: μήνυμα")

    print("OK" if not g.fails else f"{g.fails} αποτυχίες")
    return 1 if g.fails else 0


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if mode == "shot":
        c = boot()
        print(shot(c, "screenshot.png"))
        return 0
    only = int(sys.argv[2]) - 1 if len(sys.argv) > 2 else None
    return test(only)


if __name__ == "__main__":
    sys.exit(main())
