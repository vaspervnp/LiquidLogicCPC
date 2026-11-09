"""Αυτόματο test του Liquid Logic σε CPC 6128 χωρίς GUI.

Τρέχει τη δισκέτα στον headless emulator του ~/cpcemu (floooh/chips).

    python3 tools/headless.py shot   # build/screenshot.png μετά το φόρτωμα
    python3 tools/headless.py test   # μετάγγιση με τα πλήκτρα, screenshots
                                     # ανά φάση (build/test_*.png) και έλεγχος
                                     # των στρώσεων στη RAM (μέσω build/liquid.sym)

CPCHEADLESS=/path για άλλον φάκελο του emulator. Βγαίνει με 1 αν κάποιος
έλεγχος αποτύχει.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.environ.get("CPCHEADLESS", os.path.expanduser("~/cpcemu")))
from cpc import CPC, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_UP  # noqa: E402

DSK = os.path.join(ROOT, "build", "LiquidLogic.dsk")
SYM = os.path.join(ROOT, "build", "liquid.sym")
OUT = os.path.join(ROOT, "build")

BOT_SIZE, B_CNT, B_RAISE, B_DONE, B_LAY = 16, 3, 5, 6, 8


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


def bottles(c, sym):
    n = c.peek(sym["nbottles"])
    raw = c.read_ram(sym["bottles"], n * BOT_SIZE)
    out = []
    for i in range(n):
        b = raw[i * BOT_SIZE:(i + 1) * BOT_SIZE]
        out.append(list(b[B_LAY:B_LAY + b[B_CNT]]))
    return out


def frame_image(c):
    """Το καρέ με σωστή αναλογία (κάθε γραμμή διπλή), χωρίς το border."""
    im = c.image()
    w, h = im.size
    return im.crop((64, 20, w - 64, h - 20)).resize((w - 128, (h - 40) * 2))


def shot(c, name):
    path = os.path.join(OUT, name)
    c.screenshot(path, scale=1)
    print(path)


def test():
    sym = symbols(SYM)
    c = boot()
    fails = 0
    before = bottles(c, sym)
    shot(c, "test_0_start.png")

    c.tap_key(KEY_SPACE)                # πηγή: μπουκάλι 0
    c.run_frames(2)
    shot(c, "test_1_selected.png")
    if c.peek(sym["state"]) != 1:
        print("ΑΠΟΤΥΧΙΑ: η επιλογή δεν σήκωσε το μπουκάλι")
        fails += 1
    for k in (KEY_DOWN, KEY_RIGHT, KEY_RIGHT):  # -> μπουκάλι 7 (άδειο)
        c.tap_key(k)
    if c.peek(sym["cursor"]) != 7:
        print(f"ΑΠΟΤΥΧΙΑ: κέρσορας στο {c.peek(sym['cursor'])}, όχι στο 7")
        fails += 1
    c.tap_key(KEY_SPACE, hold_frames=1, gap_frames=0)
    frames = 0
    gif = []
    for i in range(200):
        c.run_frames(1)
        frames += 1
        gif.append(frame_image(c))
        if frames in (8, 16, 24):
            shot(c, f"test_2_pour_{frames:02d}.png")
        if c.peek(sym["state"]) == 0:
            break
    print(f"μετάγγιση: {frames} καρέ")
    c.run_frames(2)
    for _ in range(10):
        gif.append(frame_image(c))
    shot(c, "test_3_done.png")
    path = os.path.join(OUT, "pour.gif")
    gif[0].save(path, save_all=True, append_images=gif[1:], duration=20, loop=0)
    print(path)
    after = bottles(c, sym)
    exp = [b[:] for b in before]
    exp[7].append(exp[0].pop())
    if after != exp:
        print("ΑΠΟΤΥΧΙΑ: στρώσεις", after, "αναμενόταν", exp)
        fails += 1
    if c.peek(sym["p_alive"]) != 0:
        print("ΑΠΟΤΥΧΙΑ: ζωντανά σωματίδια μετά το τέλος")
        fails += 1

    # από την κάτω σειρά στην επάνω: 5 (κορυφή 6) -> 0 (κορυφή πια 6)
    before = after
    for k in (KEY_LEFT, KEY_LEFT):
        c.tap_key(k)
    c.tap_key(KEY_SPACE)
    c.tap_key(KEY_UP)
    c.tap_key(KEY_SPACE, hold_frames=1, gap_frames=0)
    gif = []
    for i in range(200):
        c.run_frames(1)
        gif.append(frame_image(c))
        if c.peek(sym["state"]) == 0:
            break
    c.run_frames(2)
    gif.append(frame_image(c))
    path = os.path.join(OUT, "pour_up.gif")
    gif[0].save(path, save_all=True, append_images=gif[1:], duration=20, loop=0)
    print(path)
    after = bottles(c, sym)
    exp = [b[:] for b in before]
    exp[0].append(exp[5].pop())
    if after != exp:
        print("ΑΠΟΤΥΧΙΑ: στρώσεις", after, "αναμενόταν", exp)
        fails += 1

    # άκυρη: 0 (κορυφή 6) -> 1 (κορυφή 4) δεν αλλάζει τίποτα
    before = after
    c.tap_key(KEY_SPACE)
    c.tap_key(KEY_RIGHT)
    c.tap_key(KEY_SPACE)
    c.run_frames(5)
    if bottles(c, sym) != before or c.peek(sym["state"]) != 0:
        print("ΑΠΟΤΥΧΙΑ: η άκυρη μετάγγιση άλλαξε κάτι")
        fails += 1
    shot(c, "test_4_end.png")
    print("OK" if not fails else f"{fails} αποτυχίες")
    return 1 if fails else 0


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "shot"
    if mode == "shot":
        c = boot()
        shot(c, "screenshot.png")
        return 0
    return test()


if __name__ == "__main__":
    sys.exit(main())
