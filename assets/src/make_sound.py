"""Παράγει τα δεδομένα ήχου του Liquid Logic για τον AY-3-8912 του CPC.

    python3 assets/src/make_sound.py   # -> assets/data/sound_data.asm

Ο AY του CPC έχει ρολόι 1 MHz: περίοδος τόνου P -> 1e6 / (16 P) Hz.

  note_table   περίοδοι για τις νότες 1..72 (C1..B6, 0 = παύση)
  sfx_*        εφέ για το κανάλι B: ανά καρέ dw περίοδος (bit 15 = θόρυβος,
               τότε τα bits 0-4 είναι η περίοδος θορύβου), db ένταση·
               ένταση #FF = τέλος
  music_a/c    η μελωδία του τίτλου (κανάλι A) και το μπάσο (κανάλι C):
               db νότα, καρέ· #FF = από την αρχή

Η μελωδία είναι πρωτότυπη: τέσσερις φράσεις των 16 βημάτων σε λα ελάσσονα.
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "data", "sound_data.asm")

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
CLOCK = 1_000_000


def note(name):
    """'A4' -> δείκτης 1..72 (C1 = 1)."""
    octave = int(name[-1])
    return (octave - 1) * 12 + NAMES.index(name[:-1]) + 1


def freq(index):
    midi = index + 23                   # C1 = MIDI 24
    return 440.0 * 2 ** ((midi - 69) / 12)


def period(f):
    return max(1, min(4095, round(CLOCK / (16 * f))))


# Μελωδία: (νότα, βήματα)· ένα βήμα = STEP καρέ.
STEP = 7
MELODY = [
    ("E5", 1), ("G5", 1), ("A5", 2), ("G5", 1), ("E5", 1), ("D5", 2),
    ("C5", 1), ("D5", 1), ("E5", 2), ("A4", 4),
    ("C5", 1), ("E5", 1), ("G5", 2), ("A5", 1), ("G5", 1), ("E5", 2),
    ("D5", 1), ("C5", 1), ("D5", 2), ("E5", 4),
    ("A5", 1), ("G5", 1), ("E5", 2), ("G5", 1), ("E5", 1), ("D5", 2),
    ("C5", 1), ("D5", 1), ("E5", 2), ("G4", 4),
    ("A4", 1), ("C5", 1), ("E5", 2), ("D5", 1), ("C5", 1), ("B4", 2),
    ("C5", 2), ("B4", 2), ("A4", 4),
]
BASS = ["A2", "F2", "C3", "G2", "A2", "F2", "G2", "C3",
        "F2", "G2", "C3", "A2", "F2", "G2", "E2", "A2"]


def tone(f, vol):
    return (period(f), vol)


def noise(p, vol):
    return (0x8000 | p, vol)


def sweep(f0, f1, frames, v0, v1):
    out = []
    for k in range(frames):
        t = k / max(1, frames - 1)
        out.append(tone(f0 * (f1 / f0) ** t, round(v0 + (v1 - v0) * t)))
    return out


def arp(names, frames, v0=13, decay=1):
    out = []
    for n in names:
        for k in range(frames):
            out.append(tone(freq(note(n)), max(0, v0 - k * decay)))
    return out


SFX = {
    # επιλογή πηγής: σύντομο «πλινκ» προς τα πάνω
    "select": sweep(600, 1200, 4, 12, 8),
    # ακύρωση: προς τα κάτω
    "cancel": sweep(900, 450, 4, 10, 5),
    # άκυρη κίνηση / αδιέξοδο: χαμηλό βουητό
    "error": [tone(110 if k % 2 else 104, 13 - k) for k in range(10)],
    # φελλός: «ποπ» θορύβου και ένας ψηλός τόνος
    "cork": [noise(6, 14), noise(3, 11)] + sweep(1400, 1800, 5, 12, 4),
    # νίκη: άρπισμα πάνω
    "win": arp(["C5", "E5", "G5", "C6"], 5, 13, 1) + arp(["E6"], 12, 13, 1),
    # ξεκλείδωμα / ξεπάγωμα: δύο νότες καμπανάκι
    "chime": arp(["G5", "D6"], 6, 12, 2),
    # undo: γρήγορο προς τα κάτω
    "undo": sweep(1000, 500, 5, 11, 6),
    # έξτρα μπουκάλι: προς τα πάνω, πιο μακρύ
    "extra": sweep(300, 900, 10, 13, 8),
    # τέλος χρόνου / κινήσεων: τέσσερις νότες προς τα κάτω
    "timeup": arp(["E4", "D4", "C4", "A3"], 7, 13, 1),
    # μενού: κλικ του κέρσορα
    "tick": [tone(2000, 9), tone(2000, 4)],
}


def main():
    lines = [
        "; sound_data.asm — ΠΑΡΑΓΕΤΑΙ από το assets/src/make_sound.py, μην το αλλάζεις με το χέρι",
        "",
        f"MUSIC_STEP      equ {STEP}",
        "",
        "; περίοδοι τόνου για τις νότες 0..72 (0 = παύση, 1 = C1)",
        "note_table:",
    ]
    table = [0] + [period(freq(i)) for i in range(1, 73)]
    for i in range(0, len(table), 12):
        lines.append("        dw " + ",".join(str(x) for x in table[i:i + 12]))
    for name, frames in SFX.items():
        lines.append("")
        lines.append(f"sfx_{name}:")
        for p, v in frames:
            lines.append(f"        dw #{p:04X}")
            lines.append(f"        db {max(0, min(15, v))}")
        lines.append("        dw 0")
        lines.append("        db #FF")
    lines.append("")
    lines.append("; μελωδία του τίτλου (κανάλι A): νότα, καρέ")
    lines.append("music_a:")
    for n, steps in MELODY:
        lines.append(f"        db {note(n)},{steps * STEP}    ; {n}")
    lines.append("        db #FF")
    assert sum(s for _, s in MELODY) == 4 * len(BASS)
    lines.append("")
    lines.append("; μπάσο (κανάλι C)")
    lines.append("music_c:")
    for n in BASS:
        lines.append(f"        db {note(n)},{4 * STEP}    ; {n}")
    lines.append("        db #FF")
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(OUT)


if __name__ == "__main__":
    main()
