# Liquid Logic — Manual

*A liquid sorting puzzle for the Amstrad CPC 6128*

## Loading

Put the disc in drive A and type:

```
RUN"DISC
```

The loading screen appears first; the levels and the game load while you
look at it (about 14 seconds). Your progress (unlocked levels and stars,
options, statistics, medals, your seed) is written to the disc, in
`LIQUID.SAV`, when you leave the win screen or the options and something has
changed (the HUD shows `SAVING...` for a few seconds), and loaded on the next
start. Files from older versions are read too. The disc must not be write-protected; if
it is, the game plays normally but progress is not kept.

## The goal

Each bottle holds layers of coloured liquid. Pour from bottle to bottle until
every bottle holds **a single colour** (or is empty). A full single-colour
bottle gets a cork.

A pour is allowed when the target bottle has room and is empty or has **the
same colour** on top. The whole top run of that colour moves, as much as fits.
An invalid move buzzes and the bottle bounces.

## Controls

| Key | Action |
|---|---|
| Arrows / joystick | cursor: ← → along the row, ↑ ↓ change row |
| SPACE / fire | 1st press: the bottle to pour **from** (it lifts); 2nd press: the bottle to pour **into** (the first one flies next to it, tilts and pours) |
| SPACE on the same / ESC | cancel the selection |
| ESC (nothing selected) | pause: ESC resume, R restart, M menu |
| U | undo (5 per level) |
| R | restart the level |
| E | one extra empty bottle, once, where the HUD shows `E+` |
| M | on the win, pause or time-up screen: level select |

## Screens

- **Title** — SPACE for level select, R for Relax mode, D for Relax with a
  seed, O for options, H for help, S for statistics.
- **Options** (O) — ↑ ↓ to choose, SPACE or ← → to change, ESC to go back.
  `MUSIC`/`SOUND FX` on/off, `SPEED` `NORMAL` or `FAST` (the bottle flies
  faster), `THEME` `CLASSIC` or `NEON` (unlocked after level 100), `KEYS`
  `REDEFINE`: press in turn the keys for left, right, up, down and fire (not
  ESC). The joystick always works.
- **Help** (H) — 4 pages: SPACE/→ next, ← previous, ESC back.
- **Cards** — the first time a level has a special type (ice, lock, ...), a
  card explains it with an example before the level starts (SPACE to go on;
  the clock doesn't run).
- **Statistics** (S) — levels solved, stars, perfect levels (3 stars), pours,
  Relax puzzles, and the 12 medals: yellow the ones you have, grey the rest.
  Pick one with the arrows to see what it takes.
- **Level select** — 100 cells. Grey: locked. White: available. Yellow:
  solved, with their stars below. Arrows and SPACE; ESC back to the title.
- **Level** — the HUD on top: `LV` level, `MOVES` moves (or `LEFT` moves
  remaining), `UNDO` undos left, `TIME` time, `E+` extra bottle available.

## Stars

Every level has a **par**: the fewest moves the computer found.

| Stars | Moves |
|---|---|
| ★★★ | up to par |
| ★★ | up to par + par/4 + 1 |
| ★ | more |

The best result per level is kept. Each solved level unlocks the next one.

## Special bottles and levels

| What you see | What it means |
|---|---|
| Dark cyan with "?" | **hidden layer**: revealed when it reaches the top. A pour stops at it, even if it is the same colour |
| White crystals and a number | **frozen**: can't pour from or into it. The number drops with every move; at 0 it thaws |
| A padlock in a colour | **locked**: opens when a bottle of that colour is completed |
| White bulb on the neck | **dropper**: pours one layer at a time |
| Stripes over the body | **curtain**: you can't see inside until the first pour into or out of it |
| White notches on the walls | **different size**: holds fewer layers (one notch per layer boundary) |
| Thinner layers | **tall bottle**: 5 or 6 layers |
| `LEFT n` in the HUD | **move limit**: at 0 without a solution, U or R |
| `TIME n` in the HUD | **timer**: at 0, R to try again |

Every 10th level is a **Challenge**: several types together and one more colour.

## Relax mode

From the title, press **R**. Endless random levels: 5 to 8 colours, 4 layers,
two empty bottles plus the extra one (E), with no special bottles, timer,
stars or saving. The HUD shows `RELAX`.

| Key | Action |
|---|---|
| SPACE on the win screen | next random level |
| R | the same level from the start |
| ESC, then SPACE | pause and get another level (if you don't like this one) |
| M / ESC on the win screen | back to the title |

Nearly all of them can be solved; if you get stuck, use U, E or another level.

### With a seed

From the title, press **D**. Type 4 digits (DEL erases) and SPACE or RETURN.
The same seed gives the same puzzles, in the same order, on every CPC: tell a
friend your seed and play the same ones. The HUD shows the seed, and the win
line which puzzle of the seed you solved (e.g. `2026-3`).

## Medals

| Medal | How |
|---|---|
| FIRST DROP | your first solved level |
| TEN DOWN / HALFWAY / CENTURY | 10 / 50 / 100 levels solved |
| PERFECT TEN / PERFECTIONIST | 3 stars on 10 / on all levels |
| UNWINDING / ZEN MASTER | 10 / 100 Relax puzzles |
| NO REGRETS | a level from 30 on without any undo |
| CLOSE CALL | a timed level with 10 seconds or less left |
| BUSY HANDS | 1000 pours |
| GARDENER | a seeded puzzle |

When you earn one, the win line alternates with `MEDAL: ...`.

## The ending

Solve level 100 too and press SPACE: a celebration awaits, and the **NEON**
theme (black background, pink glass) unlocks in the options.

## When you're stuck

When there is no valid move, the HUD shows `NO MOVES!`. Press **U** to go
back, **R** to start over, or **E** for an extra bottle where allowed.

Tips:

- Keep one bottle empty for as long as you can.
- Collect first the colours that are already on top of several bottles.
- With hidden layers, open the bottles with the fewest "?" first.
