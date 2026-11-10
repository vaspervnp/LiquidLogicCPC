"""Βίντεο 2 λεπτών του Liquid Logic από τον headless CPC.

    python3 tools/video.py      # -> build/liquidlogic.mp4 (χρειάζεται ffmpeg)

Παίζει σαν παίκτης με τα πλήκτρα: οθόνη φόρτωσης, τίτλος, οδηγίες,
επιλογές, στατιστικά, η πίστα 1 ως το τέλος (άκυρη κίνηση, undo), κομμάτια
από τις πίστες 80 και 100 με τις κάρτες των ειδικών τύπων, η «Χαλάρωση» με
seed και, στο τέλος, η οθόνη μετά την πίστα 100. Κάθε καρέ (50 το
δευτερόλεπτο) πάει στο ffmpeg και οι registers του AY στο WAV του
tools/sound_wav.py.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import headless as h  # noqa: E402
import levels  # noqa: E402
import sound_wav  # noqa: E402
from cpc import KEY_DOWN, KEY_SPACE  # noqa: E402

FRAMES = 50 * 120
MP4 = os.path.join(h.OUT, "liquidlogic.mp4")
WAV = os.path.join(h.OUT, "video_sound.wav")
SILENT = os.path.join(h.OUT, "video_silent.mp4")


class Done(Exception):
    pass


def recording(c, ff, log):
    """Κάθε καρέ: εικόνα στο ffmpeg, registers του AY στο log."""
    run = c.run_frames

    def run_frames(n=1):
        for _ in range(n):
            if len(log) >= FRAMES:
                raise Done
            run(1)
            log.append(c.psg_regs())
            ff.stdin.write(h.frame_image(c).tobytes())

    def tap_key(key, hold_frames=3, gap_frames=4):
        c.key_down(key)
        run_frames(hold_frames)
        c.key_up(key)
        run_frames(gap_frames)

    c.run_frames = run_frames
    c.tap_key = tap_key


def human(g, moves, wait=8, keep=0):
    """Μεταγγίσεις με μικρή ανάσα ανάμεσα, για να φαίνεται ο κέρσορας·
    σταματάει όταν μένουν λιγότερα από keep καρέ."""
    for i, j, *_ in moves:
        if len(g.log) > FRAMES - keep:
            return
        g.c.run_frames(wait)
        g.pour(i, j)


def cards(g, first=100, rest=40):
    """Οι κάρτες νέων ειδικών τύπων: η πρώτη για λίγο, οι άλλες γρήγορα."""
    t = first
    while g.peek("mode") == h.MODE_CARD:
        g.c.run_frames(t)
        g.key(KEY_SPACE)
        g.c.run_frames(5)
        t = rest
    g.c.run_frames(30)


def jump(g, idx):
    """Πίστα idx (από 0) με R, χωρίς αποθήκευση στη δισκέτα."""
    g.c.write_ram(g.sym["save_dirty"], b"\0")
    g.c.write_ram(g.sym["level"], bytes([idx]))
    g.key(ord("r"))
    g.c.run_frames(20)
    cards(g)


def to_title(g):
    c = g.c
    c.write_ram(g.sym["save_dirty"], b"\0")
    g.key(0x03)
    c.run_frames(20)
    g.key(ord("m"))
    c.run_frames(40)
    g.key(0x03)
    c.run_frames(50)


def script(g, levs, still):
    c = g.c
    for _ in range(50 * 3):             # η οθόνη φόρτωσης, σιωπηλή
        if len(g.log) >= FRAMES:
            raise Done
        g.log.append([0] * 16)
        g.ff.stdin.write(still.tobytes())
    c.run_frames(50 * 5)                # τίτλος με τη μουσική
    g.key(ord("h"))                     # οδηγίες
    c.run_frames(130)
    g.key(KEY_SPACE)
    c.run_frames(110)
    g.key(0x03)
    c.run_frames(20)
    g.key(ord("o"))                     # επιλογές (χωρίς αλλαγές)
    c.run_frames(40)
    for _ in range(3):
        g.key(KEY_DOWN)
        c.run_frames(12)
    c.run_frames(30)
    g.key(0x03)
    c.run_frames(20)
    g.key(ord("s"))                     # στατιστικά
    c.run_frames(60)
    for _ in range(3):
        g.key(KEY_DOWN)
        c.run_frames(15)
    c.run_frames(30)
    g.key(0x03)
    c.run_frames(30)
    g.key(KEY_SPACE)
    c.run_frames(40)                    # επιλογή πίστας
    g.key(KEY_SPACE)
    c.run_frames(40)

    # πίστα 1: άκυρη κίνηση, μια μετάγγιση και undo, μετά όλη η λύση
    lv = levs[0]
    b = lv["bottles"]
    bad = next((a, d) for a in range(len(b)) for d in range(len(b))
               if a != d and b[a]["layers"] and b[d]["layers"] and
               b[a]["layers"][-1] != b[d]["layers"][-1])
    human(g, [bad])
    c.run_frames(30)
    human(g, lv["solution"][:1])
    c.run_frames(20)
    g.key(ord("u"))
    c.run_frames(30)
    human(g, lv["solution"])
    c.run_frames(50 * 3)                # νίκη, αστέρια, μετάλλιο

    # πίστα 80: κάρτες (πάγος, κουρτίνα, σταγονόμετρο)
    c.write_ram(g.sym["unlocked"], bytes([100]))
    jump(g, 79)
    human(g, levs[79]["solution"][:5])
    c.run_frames(30)

    # πίστα 100: κάρτες, χρονόμετρο, και το έξτρα μπουκάλι
    jump(g, 99)
    human(g, levs[99]["solution"][:4])
    c.run_frames(20)
    g.key(ord("e"))
    c.run_frames(30)
    human(g, levs[99]["solution"][4:6])
    c.run_frames(30)

    # «Χαλάρωση» με seed: D, 2026, SPACE
    to_title(g)
    g.key(ord("d"))
    c.run_frames(30)
    for k in "2026":
        g.key(ord(k))
        c.run_frames(8)
    c.run_frames(40)
    g.key(KEY_SPACE)
    c.run_frames(40)
    lay = g.layers()
    sol = levels.solve(tuple(levels.bottle(4, x) for x in lay)) or []
    human(g, sol, keep=50 * 9)
    if g.peek("state") == h.ST_WIN:
        c.run_frames(50 * 2)

    # το τέλος (μετά την πίστα 100): νίκη στην πίστα 100 και SPACE
    to_title(g)
    g.key(KEY_SPACE)
    c.run_frames(20)
    g.key(KEY_SPACE)
    c.run_frames(30)
    cards(g, 5, 5)
    for k, v in (("save_dirty", 0), ("level", 99), ("state", h.ST_WIN), ("relax", 0), ("timer_on", 0)):
        c.write_ram(g.sym[k], bytes([v]))
    g.key(KEY_SPACE)
    c.run_frames(50 * 10)


def main():
    sym = h.symbols(h.SYM)
    levs = levels.levels()
    shots = []
    c = h.boot(shots=shots)
    g = h.Game(c, sym)
    still = max(shots[:-1], key=lambda im: len(set(im.getdata())))  # η οθόνη φόρτωσης
    w, ht = h.frame_image(c).size
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{w}x{ht}", "-r", "50", "-i", "-",
         "-vf", "scale=iw*2:ih*2:flags=neighbor", "-c:v", "libx264", "-preset", "medium",
         "-crf", "18", "-pix_fmt", "yuv420p", SILENT], stdin=subprocess.PIPE)
    log = []
    g.log, g.ff = log, ff
    recording(c, ff, log)
    try:
        script(g, levs, still)
    except Done:
        pass
    ff.stdin.close()
    ff.wait()
    sound_wav.render(log, WAV)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", SILENT, "-i", WAV,
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "128k", "-shortest", MP4], check=True)
    os.remove(SILENT)
    print(f"{len(log)} καρέ, {g.fails} αποτυχίες")
    print(MP4)
    return 1 if g.fails else 0


if __name__ == "__main__":
    sys.exit(main())
