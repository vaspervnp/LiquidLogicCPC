"""Βίντεο 2 λεπτών του Liquid Logic από τον headless CPC.

    python3 tools/video.py      # -> build/liquidlogic.mp4 (χρειάζεται ffmpeg)

Παίζει σαν παίκτης με τα πλήκτρα: τίτλος, επιλογή πίστας, η πίστα 1 ως το
τέλος (άκυρη κίνηση, undo), κομμάτια από τις πίστες 80 και 100 (πάγος,
κουρτίνα, σταγονόμετρο, χρονόμετρο, έξτρα μπουκάλι) και η «Χαλάρωση».
Κάθε καρέ (50 το δευτερόλεπτο) πάει στο ffmpeg και οι registers του AY
στο WAV του tools/sound_wav.py.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import headless as h  # noqa: E402
import levels  # noqa: E402
import sound_wav  # noqa: E402
from cpc import KEY_SPACE  # noqa: E402

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


def human(g, moves, wait=8):
    """Μεταγγίσεις με μικρή ανάσα ανάμεσα, για να φαίνεται ο κέρσορας."""
    for i, j, *_ in moves:
        g.c.run_frames(wait)
        g.pour(i, j)


def jump(g, idx):
    """Πίστα idx (από 0): όπως το load_level, χωρίς αποθήκευση στη δισκέτα."""
    g.c.write_ram(g.sym["save_dirty"], b"\0")
    g.load_level(idx)


def script(g, levs):
    c = g.c
    c.run_frames(50 * 7)                    # τίτλος με τη μουσική
    g.key(KEY_SPACE)
    c.run_frames(50)                        # επιλογή πίστας
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
    g.key(ord("U"))
    c.run_frames(30)
    human(g, lv["solution"])
    c.run_frames(50 * 3)                    # νίκη, αστέρια

    # πίστα 80: πάγος, κουρτίνα, σταγονόμετρο
    c.write_ram(g.sym["unlocked"], bytes([100]))
    jump(g, 79)
    c.run_frames(40)
    human(g, levs[79]["solution"][:9])
    c.run_frames(30)

    # πίστα 100: όλα μαζί, με χρονόμετρο, και το έξτρα μπουκάλι
    jump(g, 99)
    c.run_frames(40)
    human(g, levs[99]["solution"][:5])
    c.run_frames(20)
    g.key(ord("E"))
    c.run_frames(30)
    human(g, levs[99]["solution"][5:8])
    c.run_frames(30)

    # «Χαλάρωση»: μενού -> τίτλος -> R, λύση μιας τυχαίας, μετά κι άλλες
    g.c.write_ram(g.sym["save_dirty"], b"\0")
    g.key(0x03)                             # παύση
    c.run_frames(30)
    g.key(ord("M"))                         # -> επιλογή πίστας
    c.run_frames(40)
    g.key(0x03)                             # -> τίτλος
    c.run_frames(60)
    g.key(ord("R"))
    c.run_frames(40)
    g.check(g.peek("relax") == 1, "δεν μπήκε στη «Χαλάρωση»")
    while True:
        lay = g.layers()
        sol = levels.solve(tuple(levels.bottle(4, x) for x in lay))
        human(g, sol or [])
        c.run_frames(50 * 3)                # «SOLVED!»
        g.key(KEY_SPACE)
        c.run_frames(40)


def main():
    sym = h.symbols(h.SYM)
    levs = levels.levels()
    c = h.boot()
    g = h.Game(c, sym)
    w, ht = h.frame_image(c).size
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{w}x{ht}", "-r", "50", "-i", "-",
         "-vf", "scale=iw*2:ih*2:flags=neighbor", "-c:v", "libx264", "-preset", "medium",
         "-crf", "18", "-pix_fmt", "yuv420p", SILENT], stdin=subprocess.PIPE)
    log = []
    recording(c, ff, log)
    try:
        script(g, levs)
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
