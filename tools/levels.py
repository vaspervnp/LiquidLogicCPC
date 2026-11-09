"""Πίστες του Liquid Logic: γεννήτρια + solver.

    python3 tools/levels.py            # γράφει assets/data/levels.asm
    python3 tools/levels.py --show     # τυπώνει τις πίστες και τις λύσεις

Κάθε πίστα: τυχαίο ανακάτεμα των στρώσεων (σταθερό seed ανά πίστα), που
γίνεται δεκτό μόνο αν ο solver τη λύνει και η ελάχιστη λύση (par) είναι
αρκετά μεγάλη. Ο solver (BFS) ξέρει όλους τους ειδικούς τύπους (plan.md §3)
και χρησιμοποιείται και από τα tests (tools/headless.py).

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
HIDDEN = 0x80               # bit 7 στρώσης: κρυμμένη

# header flags
LF_HIDDEN, LF_MOVES, LF_TIMER, LF_EXTRA = 1, 2, 4, 8
# bflags: bit 0-2 χωρητικότητα (0 = της πίστας), bit 3 σταγονόμετρο, bit 4 κουρτίνα
BF_DROPPER, BF_CURTAIN = 8, 16

# Πίστες: χρώματα, άδεια, χωρητικότητα, ελάχιστο par και ειδικοί τύποι:
#   hidden    κρυμμένες όλες οι στρώσεις κάτω από την κορυφή
#   freeze    [κινήσεις, ...]: παγωμένα μπουκάλια
#   lock      πλήθος μπουκαλιών με λουκέτο χρώματος
#   moves     όριο = par + moves
#   small     χωρητικότητες μικρών άδειων μπουκαλιών (αντί για ένα άδειο)
#   dropper   πλήθος σταγονόμετρων
#   curtain   πλήθος με κουρτίνα
#   timer     δευτερόλεπτα = par * timer + 20
#   extra     επιτρέπεται το έξτρα μπουκάλι (E)
CURVE = [
    dict(colours=3, par=4),
    dict(colours=3, par=5),
    dict(colours=4, par=6),
    dict(colours=4, par=6, hidden=True),
    dict(colours=5, par=8),
    dict(colours=4, par=6, freeze=[3]),
    dict(colours=5, par=8, moves=3),
    dict(colours=4, par=6, cap=5),
    dict(colours=5, par=8, hidden=True, moves=4),
    dict(colours=5, par=8, lock=1),
    dict(colours=5, par=8, empties=1, small=[2, 3]),
    dict(colours=4, par=7, empties=1, extra=True),
    dict(colours=5, par=8, dropper=2),
    dict(colours=5, par=8, curtain=2),
    dict(colours=5, par=9, timer=8),
    dict(colours=5, par=8, cap=6),
    dict(colours=6, par=10, freeze=[2, 5], hidden=True),
    dict(colours=6, par=10, lock=2, moves=4),
    dict(colours=6, par=10, dropper=2, curtain=2),
    dict(colours=7, par=12, hidden=True, lock=1, freeze=[4], moves=5),
]


def is_done(b):
    cap, layers = b[0], b[-1]
    return len(layers) == cap and len(set(x & 0x7F for x in layers)) == 1


# Μπουκάλι: (cap, dropper, lock, freeze, layers). Οι στρώσεις με το bit
# κρυμμένης: η μετάγγιση σταματάει σε κρυμμένη στρώση (ο παίκτης δεν την
# ξέρει), και η νέα κορυφή της πηγής αποκαλύπτεται.
def bottle(cap, layers, dropper=False, lock=0, freeze=0):
    return (cap, dropper, lock, freeze, tuple(layers))


def solved(bottles):
    return all(not b[-1] or is_done(b) for b in bottles)


def usable(b, bottles, moves_made):
    cap, dropper, lock, freeze, layers = b
    if freeze and moves_made < freeze:
        return False
    if lock and not any(is_done(o) and o[-1][0] & 0x7F == lock for o in bottles):
        return False
    return True


def moves(bottles, moves_made):
    """Έγκυρες μεταγγίσεις (i, j, n), όπως στο pour.asm. Παραλείπει τις
    άσκοπες: ολόκληρο μονόχρωμο μπουκάλι σε άδειο."""
    for i, a in enumerate(bottles):
        layers = a[-1]
        if not layers or is_done(a) or not usable(a, bottles, moves_made):
            continue
        top = layers[-1]
        run = 1
        while run < len(layers) and layers[-1 - run] == top:
            run += 1
        if a[1]:
            run = 1
        for j, b in enumerate(bottles):
            if i == j or len(b[-1]) >= b[0] or not usable(b, bottles, moves_made):
                continue
            if b[-1] and b[-1][-1] != top:
                continue
            if not b[-1] and run == len(layers) and not a[1]:
                continue
            yield i, j, min(run, b[0] - len(b[-1]))


def apply(bottles, move):
    i, j, n = move
    s = [list(b[-1]) for b in bottles]
    for _ in range(n):
        s[j].append(s[i].pop())
    if s[i]:
        s[i][-1] &= 0x7F                    # αποκάλυψη της νέας κορυφής
    out = []
    for k, b in enumerate(bottles):
        layers = s[k]
        if len(layers) == b[0] and len(set(x & 0x7F for x in layers)) == 1:
            layers = [x & 0x7F for x in layers]   # ολοκληρωμένο: όλο ορατό
        out.append(b[:-1] + (tuple(layers),))
    return tuple(out)


def solve(bottles, limit=1_500_000):
    """Ελάχιστη λύση ως λίστα (i, j, n), ή None."""
    start = tuple(bottles)
    if solved(start):
        return []
    max_freeze = max([b[3] for b in start] + [0])
    key = lambda s, d: (tuple(sorted(s)), min(d, max_freeze))  # noqa: E731
    parent = {key(start, 0): None}
    queue = deque([(start, 0)])
    while queue:
        s, d = queue.popleft()
        for m in moves(s, d):
            t = apply(s, m)
            k = key(t, d + 1)
            if k in parent:
                continue
            parent[k] = (s, d, m)
            if solved(t):
                path, cur, cd = [m], s, d
                while parent[key(cur, cd)] is not None:
                    ps, pd, pm = parent[key(cur, cd)]
                    path.append(pm)
                    cur, cd = ps, pd
                return path[::-1]
            if len(parent) > limit:
                return None
            queue.append((t, d + 1))
    return None


def generate(index, spec):
    rng = random.Random(1000 + index)
    colours = spec["colours"]
    cap = spec.get("cap", 4)
    empties = spec.get("empties", 2)
    small = spec.get("small", [])
    for attempt in range(3000):
        pens = rng.sample(PENS, colours)
        units = [p for p in pens for _ in range(cap)]
        rng.shuffle(units)
        full = [units[k * cap:(k + 1) * cap] for k in range(colours)]
        if any(len(set(b)) == 1 for b in full):
            continue
        if any(b[-1] == b[-2] == b[-3] for b in full):
            continue
        bots = [dict(cap=cap, layers=b, dropper=False, lock=0, freeze=0, curtain=False) for b in full]
        order = list(range(colours))
        rng.shuffle(order)
        k = 0
        for f in spec.get("freeze", []):
            bots[order[k]]["freeze"] = f
            k += 1
        for _ in range(spec.get("lock", 0)):
            b = bots[order[k]]
            others = [p for p in pens if p not in b["layers"]]
            if not others:
                break
            b["lock"] = rng.choice(others)
            k += 1
        for _ in range(spec.get("dropper", 0)):
            bots[order[k]]["dropper"] = True
            k += 1
        for _ in range(spec.get("curtain", 0)):
            bots[order[k % colours]]["curtain"] = True
            k += 1
        bots += [dict(cap=cap, layers=[], dropper=False, lock=0, freeze=0, curtain=False)
                 for _ in range(empties)]
        bots += [dict(cap=c, layers=[], dropper=False, lock=0, freeze=0, curtain=False) for c in small]
        if spec.get("hidden"):
            for b in bots:
                b["layers"] = [x | HIDDEN for x in b["layers"][:-1]] + b["layers"][-1:]
        state = [bottle(b["cap"], b["layers"], b["dropper"], b["lock"], b["freeze"]) for b in bots]
        sol = solve(state)
        if sol is not None and len(sol) >= spec["par"]:
            return bots, sol
    raise RuntimeError(f"πίστα {index + 1}: δεν βρέθηκε")


def levels():
    out = []
    for i, spec in enumerate(CURVE):
        bots, sol = generate(i, spec)
        par = len(sol)
        cap = spec.get("cap", 4)
        flags = 0
        if spec.get("hidden"):
            flags |= LF_HIDDEN
        moves_limit = par + spec["moves"] if "moves" in spec else 0
        if moves_limit:
            flags |= LF_MOVES
        timer = (par * spec["timer"] + 20 + 3) // 4 if "timer" in spec else 0
        if timer:
            flags |= LF_TIMER
        if spec.get("extra"):
            flags |= LF_EXTRA
        out.append(dict(bottles=bots, cap=cap, par=par, solution=sol, flags=flags,
                        moves=moves_limit, timer=timer))
    return out


def state_of(lv):
    """Κατάσταση για τον solver / το apply."""
    return tuple(bottle(b["cap"], b["layers"], b["dropper"], b["lock"], b["freeze"])
                 for b in lv["bottles"])


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
        lines.append(f"        db {lv['flags']},{len(lv['bottles'])},{lv['cap']},{lv['moves']},{lv['timer']},{lv['par']}")
        for b in lv["bottles"]:
            bf = (b["cap"] if b["cap"] != lv["cap"] else 0) | (BF_DROPPER if b["dropper"] else 0) \
                | (BF_CURTAIN if b["curtain"] else 0)
            lines.append(f"        db {bf},{b['freeze']},{b['lock']}," +
                         ",".join(str(x) for x in [len(b["layers"])] + b["layers"]))
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    levs = levels()
    if "--show" in sys.argv:
        for i, lv in enumerate(levs):
            print(f"πίστα {i + 1}: par {lv['par']} flags {lv['flags']} moves {lv['moves']} "
                  f"timer {lv['timer'] * 4}s")
            for b in lv["bottles"]:
                print("    ", b)
        return
    write_asm(levs)
    print(OUT)


if __name__ == "__main__":
    main()
