"""Ηχογράφηση από τον headless CPC: οι registers του AY ανά καρέ -> WAV.

    python3 tools/sound_wav.py

Ο headless emulator δεν βγάζει ήχο, αλλά δείχνει τους registers του AY. Τους
διαβάζουμε 50 φορές το δευτερόλεπτο (όσο συχνά τους αλλάζει και ο driver)
και τους παίζουμε με έναν απλό συνθεσάιζερ AY: τετράγωνα κύματα, θόρυβος με
LFSR 17 bits, λογαριθμικές εντάσεις (όπως στο Space Force C). Βγάζει:

    build/sound_title.wav   η μουσική του τίτλου
    build/sound_game.wav    η πίστα 1 ως το τέλος: επιλογή, άκυρη κίνηση,
                            γουργουρητό των μεταγγίσεων, φελλοί, νίκη

Βγαίνει με 1 αν ο τίτλος είναι σιωπηλός ή αν η πίστα δεν βγάζει εφέ/γουργουρητό.
"""
import os
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import headless as h  # noqa: E402
import levels  # noqa: E402
from cpc import KEY_SPACE  # noqa: E402

RATE = 22050
AY_CLOCK = 1000000
VOL = [0.0] + [10 ** ((v - 15) * 1.5 / 10) for v in range(1, 16)]


def render(frames, path):
    """frames: λίστα από 16 registers ανά 1/50 s -> WAV mono 16 bits."""
    per_frame = RATE // 50
    step = AY_CLOCK / 8 / RATE          # ο AY μετράει σε 1/8 του ρολογιού
    phase = [0.0, 0.0, 0.0]
    out = [0, 0, 0]
    nphase, lfsr, nbit = 0.0, 1, 1
    samples = bytearray()
    for r in frames:
        tp = [max(1, r[2 * c] | (r[2 * c + 1] & 15) << 8) for c in range(3)]
        npd = max(1, r[6] & 31)
        mix = r[7]
        vols = [VOL[r[8 + c] & 15] for c in range(3)]
        for _ in range(per_frame):
            for c in range(3):
                phase[c] += step
                while phase[c] >= tp[c]:
                    phase[c] -= tp[c]
                    out[c] ^= 1
            nphase += step / 2
            while nphase >= npd:
                nphase -= npd
                nbit = lfsr & 1
                lfsr = (lfsr >> 1) | (((lfsr ^ (lfsr >> 3)) & 1) << 16)
            s = 0.0
            for c in range(3):
                tone = out[c] | (mix >> c & 1)
                noise = nbit | (mix >> (c + 3) & 1)
                if tone & noise:
                    s += vols[c]
            samples += struct.pack('<h', int((s / 3 - 0.25) * 30000))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(samples))


def recording(c, log):
    """Κάθε καρέ του emulator γράφει τους registers στο log (και τα πατήματα
    πλήκτρων περνάνε από εδώ, ώστε να ηχογραφούνται κι αυτά)."""
    run = c.run_frames

    def run_frames(n=1):
        for _ in range(n):
            run(1)
            log.append(c.psg_regs())

    def tap_key(key, hold_frames=3, gap_frames=4):
        c.key_down(key)
        run_frames(hold_frames)
        c.key_up(key)
        run_frames(gap_frames)

    c.run_frames = run_frames
    c.tap_key = tap_key


def main():
    sym = h.symbols(h.SYM)
    levs = levels.levels()
    c = h.boot()
    log = []
    recording(c, log)
    c.run_frames(50 * 12)
    title = log[:]
    render(title, os.path.join(h.OUT, 'sound_title.wav'))

    del log[:]
    g = h.Game(c, sym)
    g.key(KEY_SPACE)                    # τίτλος -> επιλογή
    c.run_frames(25)
    g.key(KEY_SPACE)                    # -> πίστα 1
    c.run_frames(25)
    lv = levs[0]
    b = lv["bottles"]
    bad = next(((a, d) for a in range(len(b)) for d in range(len(b))
                if a != d and b[a]["layers"] and b[d]["layers"] and
                b[a]["layers"][-1] != b[d]["layers"][-1]), None)
    if bad:
        g.pour(*bad)                    # άκυρη: βουητό
    g.play(lv, "πίστα 1")
    c.run_frames(50 * 2)
    render(log, os.path.join(h.OUT, 'sound_game.wav'))

    loud = sum(1 for r in title if (r[8] | r[10]) & 15)
    sfx = sum(1 for r in log if r[9] & 15)
    plip = sum(1 for r in log if r[8] & 15)
    print(f"τίτλος: {loud}/{len(title)} καρέ με μουσική")
    print(f"πίστα 1: {sfx} καρέ με εφέ, {plip} με γουργουρητό, {len(log)} συνολικά")
    for name in ("sound_title.wav", "sound_game.wav"):
        print(os.path.join(h.OUT, name))
    ok = loud > len(title) // 2 and sfx > 0 and plip > 0 and not g.fails
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
