"""Πίστες του Liquid Logic: γεννήτρια + solver.

    python3 tools/levels.py            # γράφει assets/data/levels.asm (+ .json)
    python3 tools/levels.py --show     # τυπώνει τις πίστες

Οι πίστες (με τις λύσεις τους) μένουν στο assets/data/levels.json, που το
διαβάζουν τα tests· ξαναπαράγονται μόνο όταν αλλάξει αυτό το αρχείο.

Κάθε πίστα: τυχαίο ανακάτεμα των στρώσεων (σταθερό seed ανά πίστα), που
γίνεται δεκτό μόνο αν ο solver τη λύνει και η ελάχιστη λύση (par) είναι
αρκετά μεγάλη. Ο solver (BFS) ξέρει όλους τους ειδικούς τύπους (plan.md §3)
και χρησιμοποιείται και από τα tests (tools/headless.py).

Μορφή (plan.md §6):
  header:  db flags, μπουκάλια, χωρητικότητα, κινήσεις, χρονόμετρο, par
  μπουκάλι: db bflags, freeze, lock, πλήθος, στρώσεις από κάτω...
"""

import heapq
import itertools
import json
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

# Πίστα: χρώματα, άδεια, χωρητικότητα, ελάχιστο par και ειδικοί τύποι:
#   hidden    κρυμμένες όλες οι στρώσεις κάτω από την κορυφή
#   freeze    [κινήσεις, ...]: παγωμένα μπουκάλια
#   lock      πλήθος μπουκαλιών με λουκέτο χρώματος
#   moves     όριο = par + moves
#   small     χωρητικότητες μικρών άδειων μπουκαλιών (αντί για ένα άδειο)
#   dropper   πλήθος σταγονόμετρων
#   curtain   πλήθος με κουρτίνα
#   timer     δευτερόλεπτα = par * timer + 20
#   extra     επιτρέπεται το έξτρα μπουκάλι (E)
#
# Καμπύλη (plan.md §3): ανά δεκάδα πιστών τα χρώματα ανεβαίνουν, και κάθε
# τύπος εμφανίζεται πρώτα μόνος του και μετά σε συνδυασμούς. Κάθε 10η πίστα
# είναι «Πρόκληση» (CHALLENGE).
HIDDEN_AT = {11, 15, 19, 25, 34, 44, 54, 70, 84, 88, 93}
FREEZE_AT = {21: [3], 24: [4], 28: [3, 6], 33: [5], 37: [4, 8], 48: [5], 59: [6], 76: [6],
             86: [5, 9], 95: [7]}
MOVES_AT = {22: 4, 26: 4, 31: 3, 35: 3, 39: 3, 50: 4, 56: 3, 68: 4, 82: 5, 91: 4, 97: 4}
CAP_AT = {23: 5, 27: 5, 32: 5, 36: 6, 38: 5, 46: 5, 65: 5, 85: 6, 94: 5}
LOCK_AT = {41: 1, 45: 1, 49: 2, 53: 1, 57: 2, 66: 1, 83: 2, 92: 2, 99: 2}
SMALL_AT = {42: [2, 3], 46: [3], 51: [2, 2], 55: [3, 3], 64: [2], 87: [2, 3]}
ONE_EMPTY_AT = {43, 47, 52, 58, 71, 89}
DROPPER_AT = {61: 1, 65: 2, 69: 2, 73: 1, 77: 2, 90: 2, 96: 2}
CURTAIN_AT = {62: 1, 66: 2, 71: 1, 75: 2, 79: 2, 84: 2, 98: 2}
TIMER_AT = {63: 10, 67: 9, 72: 8, 76: 8, 81: 8, 94: 7, 100: 7}
EXTRA_AT = {64, 68, 74, 78, 89, 96, 100}
CHALLENGE = {
    10: dict(hidden=True, moves=4),
    20: dict(freeze=[4], hidden=True),
    30: dict(lock=1, moves=4),
    40: dict(cap=5, freeze=[5]),
    50: dict(lock=1, small=[3], moves=5),
    60: dict(dropper=1, curtain=2, moves=5),
    70: dict(timer=9, hidden=True, lock=1),
    80: dict(curtain=2, freeze=[6], dropper=1),
    90: dict(hidden=True, lock=1, freeze=[6], moves=5),
    100: dict(hidden=True, lock=2, freeze=[8], dropper=1, timer=7, extra=True),
}


def colours_at(n):
    if n <= 5:
        return [3, 3, 4, 4, 4][n - 1]
    for lo, hi, c0 in ((6, 20, 5), (21, 40, 6), (41, 60, 7), (61, 80, 8), (81, 100, 10)):
        if n <= hi:
            return c0 + (n - lo) * 3 // (hi - lo + 1)


def spec_at(n):
    s = dict(colours=colours_at(n))
    if n in HIDDEN_AT:
        s["hidden"] = True
    if n in FREEZE_AT:
        s["freeze"] = FREEZE_AT[n]
    if n in MOVES_AT:
        s["moves"] = MOVES_AT[n]
    if n in CAP_AT:
        s["cap"] = CAP_AT[n]
        s["colours"] = min(s["colours"], 8 if CAP_AT[n] == 5 else 7)
    if n in LOCK_AT:
        s["lock"] = LOCK_AT[n]
    if n in SMALL_AT:
        s["small"] = SMALL_AT[n]
        s["empties"] = 1
    if n in ONE_EMPTY_AT:
        s["empties"] = 1
        s["colours"] = min(s["colours"], 6)
    if n in DROPPER_AT:
        s["dropper"] = DROPPER_AT[n]
    if n in CURTAIN_AT:
        s["curtain"] = CURTAIN_AT[n]
    if n in TIMER_AT:
        s["timer"] = TIMER_AT[n]
    if n in EXTRA_AT:
        s["extra"] = True
    if n in CHALLENGE:
        s.update(CHALLENGE[n])
        s["colours"] = min(12, s["colours"] + 1)
        if "cap" in s:
            s["colours"] = min(s["colours"], 8)
    # μπουκάλια ως 14 (13 αν επιτρέπεται το έξτρα μπουκάλι)
    extra_bottles = s.get("empties", 2) + len(s.get("small", [])) + (1 if s.get("extra") else 0)
    s["colours"] = min(s["colours"], 14 - extra_bottles)
    s["par"] = 2 * s["colours"] + (2 if n > 5 else 0)
    return s


CURVE = [spec_at(n) for n in range(1, 101)]
JSON_OUT = os.path.join(ROOT, "assets", "data", "levels.json")


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


def bfs(start, limit):
    """Ελάχιστη λύση (BFS) ή None αν τελειώσει ο χώρος/το όριο κόμβων."""
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


def runs(bottles):
    """Χρωματικά τμήματα (χωρίς το bit κρυμμένης) σε όλα τα μπουκάλια."""
    n = 0
    for b in bottles:
        prev = None
        for x in b[-1]:
            x &= 0x7F
            if x != prev:
                n += 1
                prev = x
    return n


def astar(start, colours, limit, weight=2.0):
    """Weighted A*: γρήγορη (όχι απαραίτητα ελάχιστη) λύση. h = τμήματα −
    χρώματα: κάθε μετάγγιση ενώνει το πολύ δύο τμήματα."""
    max_freeze = max([b[3] for b in start] + [0])
    key = lambda s, d: (tuple(sorted(s)), min(d, max_freeze))  # noqa: E731
    count = itertools.count()
    heap = [(weight * (runs(start) - colours), next(count), 0, start)]
    parent = {key(start, 0): None}
    while heap:
        _, _, d, s = heapq.heappop(heap)
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
            heapq.heappush(heap, (d + 1 + weight * (runs(t) - colours), next(count), d + 1, t))
    return None


def solve(bottles, bfs_limit=60_000, astar_limit=150_000):
    """Λύση ως λίστα (i, j, n), ή None. Πρώτα BFS (ελάχιστη)· σε μεγάλες
    πίστες weighted A* (καλή, όχι πάντα ελάχιστη: το par είναι τότε άνω όριο)."""
    start = tuple(bottles)
    if solved(start):
        return []
    sol = bfs(start, bfs_limit)
    if sol is not None:
        return sol
    colours = len({x & 0x7F for b in start for x in b[-1]})
    return astar(start, colours, astar_limit)


def generate(index, spec):
    rng = random.Random(1000 + index)
    colours = spec["colours"]
    cap = spec.get("cap", 4)
    empties = spec.get("empties", 2)
    small = spec.get("small", [])
    for attempt in range(200):
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


def make_level(i):
    spec = CURVE[i]
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
    return dict(bottles=bots, cap=cap, par=par, solution=[list(m) for m in sol], flags=flags,
                moves=moves_limit, timer=timer)


def levels():
    """Όλες οι πίστες: από το assets/data/levels.json (αν υπάρχει και είναι
    νεότερο από αυτό το αρχείο), αλλιώς παραγωγή (παράλληλα)."""
    if os.path.exists(JSON_OUT) and os.path.getmtime(JSON_OUT) >= os.path.getmtime(__file__):
        with open(JSON_OUT) as f:
            levs = json.load(f)
        if len(levs) == len(CURVE):
            for lv in levs:
                lv["solution"] = [tuple(m) for m in lv["solution"]]
            return levs
    import multiprocessing
    with multiprocessing.Pool() as pool:
        levs = pool.map(make_level, range(len(CURVE)))
    with open(JSON_OUT, "w") as f:
        json.dump(levs, f)
    for lv in levs:
        lv["solution"] = [tuple(m) for m in lv["solution"]]
    return levs


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
    print(OUT, JSON_OUT)


if __name__ == "__main__":
    main()
