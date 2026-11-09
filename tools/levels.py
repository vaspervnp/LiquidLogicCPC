"""Πίστες του Liquid Logic: γεννήτρια + solver.

    python3 tools/levels.py            # γράφει assets/data/levels.asm
    python3 tools/levels.py --show     # τυπώνει τις πίστες και τις λύσεις

Κάθε πίστα: τυχαίο ανακάτεμα των στρώσεων (σταθερό seed ανά πίστα), που
γίνεται δεκτό μόνο αν ο solver τη λύνει και η ελάχιστη λύση (par) είναι
αρκετά μεγάλη. Ο solver (BFS) είναι και για τα tests (tools/headless.py).

Μορφή (plan.md §6):
  header:  db flags, μπουκάλια, χωρητικότητα, κινήσεις, χρονόμετρο, par
  μπουκάλι: db bflags, freeze, lock, πλήθος, στρώσεις από κάτω...
"""

import os
import random
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "data", "levels.asm")

PEN_FIRST = 4               # τα 12 υγρά: pens 4-15
PENS = list(range(PEN_FIRST, PEN_FIRST + 12))

# (χρώματα, άδεια μπουκάλια, χωρητικότητα, ελάχιστο par)
CURVE = [
    (3, 2, 4, 4),
    (3, 2, 4, 5),
    (4, 2, 4, 6),
    (4, 2, 4, 7),
    (5, 2, 4, 8),
    (5, 2, 4, 9),
    (6, 2, 4, 10),
    (6, 2, 4, 11),
    (7, 2, 4, 12),
    (7, 2, 4, 13),
]


def is_done(b, cap):
    return len(b) == cap and len(set(b)) == 1


def solved(state, cap):
    return all(not b or is_done(b, cap) for b in state)


def moves(state, cap):
    """Έγκυρες μεταγγίσεις (i, j, n), όπως στο pour.asm. Παραλείπει τις
    άσκοπες: ολόκληρο μονόχρωμο μπουκάλι σε άδειο."""
    for i, a in enumerate(state):
        if not a or is_done(a, cap):
            continue
        top = a[-1]
        run = 1
        while run < len(a) and a[-1 - run] == top:
            run += 1
        for j, b in enumerate(state):
            if i == j or len(b) == cap:
                continue
            if b and b[-1] != top:
                continue
            if not b and run == len(a):
                continue
            yield i, j, min(run, cap - len(b))


def apply(state, move):
    i, j, n = move
    s = [list(b) for b in state]
    for _ in range(n):
        s[j].append(s[i].pop())
    return tuple(tuple(b) for b in s)


def solve(state, cap, limit=2_000_000):
    """Ελάχιστη λύση ως λίστα (i, j, n), ή None."""
    start = tuple(tuple(b) for b in state)
    if solved(start, cap):
        return []
    key = lambda s: tuple(sorted(s))   # noqa: E731 — συμμετρικές καταστάσεις
    parent = {key(start): None}
    queue = deque([start])
    while queue:
        s = queue.popleft()
        for m in moves(s, cap):
            t = apply(s, m)
            k = key(t)
            if k in parent:
                continue
            parent[k] = (s, m)
            if solved(t, cap):
                path = []
                while parent[key(t)] is not None:
                    s0, m0 = parent[key(t)]
                    path.append(m0)
                    t = s0
                return path[::-1]
            if len(parent) > limit:
                return None
            queue.append(t)
    return None


def generate(index, colours, empties, cap, min_par):
    rng = random.Random(1000 + index)
    for attempt in range(500):
        pens = rng.sample(PENS, colours)
        units = [p for p in pens for _ in range(cap)]
        rng.shuffle(units)
        bottles = [units[k * cap:(k + 1) * cap] for k in range(colours)]
        if any(len(set(b)) == 1 for b in bottles):
            continue
        if any(b[-1] == b[-2] == b[-3] for b in bottles):
            continue
        state = bottles + [[] for _ in range(empties)]
        sol = solve(state, cap)
        if sol is not None and len(sol) >= min_par:
            return state, sol
    raise RuntimeError(f"πίστα {index + 1}: δεν βρέθηκε")


def levels():
    out = []
    for i, (colours, empties, cap, min_par) in enumerate(CURVE):
        state, sol = generate(i, colours, empties, cap, min_par)
        out.append({"bottles": state, "cap": cap, "par": len(sol), "solution": sol})
    return out


def write_asm(levs):
    lines = [
        "; levels.asm — ΠΑΡΑΓΕΤΑΙ από το tools/levels.py, μην το αλλάζεις με το χέρι",
        "",
        f"LEVEL_COUNT     equ {len(levs)}",
        "",
        "level_table:",
    ]
    lines += [f"        dw level_{i + 1}" for i in range(len(levs))]
    for i, lv in enumerate(levs):
        lines.append("")
        lines.append(f"level_{i + 1}:    ; par {lv['par']}")
        lines.append(f"        db 0,{len(lv['bottles'])},{lv['cap']},0,0,{lv['par']}")
        for b in lv["bottles"]:
            lines.append("        db 0,0,0," + ",".join(str(x) for x in [len(b)] + b))
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    levs = levels()
    if "--show" in sys.argv:
        for i, lv in enumerate(levs):
            print(f"πίστα {i + 1}: par {lv['par']}  {lv['bottles']}")
            print("   ", lv["solution"])
        return
    write_asm(levs)
    print(OUT)


if __name__ == "__main__":
    main()
