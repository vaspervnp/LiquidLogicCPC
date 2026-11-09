# Liquid Logic — Manual

*A liquid sorting puzzle for the Amstrad CPC 6128*

## Loading

Put the disc in drive A and type:

```
RUN"DISC
```

The 100 levels load first, then the game. Your progress (unlocked levels and
their stars) is written to the disc, in `LIQUID.SAV`, when you leave the win
screen of a level with a better result (the HUD shows `SAVING...` for a few
seconds), and loaded on the next start. The disc must not be write-protected; if
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
| SPACE / fire | 1st press: the bottle to pour **from** (it lifts); 2nd press: the bottle to pour **into** |
| SPACE on the same / ESC | cancel the selection |
| ESC (nothing selected) | pause: ESC resume, R restart, M menu |
| U | undo (5 per level) |
| R | restart the level |
| E | one extra empty bottle, once, where the HUD shows `E+` |
| M | on the win, pause or time-up screen: level select |

## Screens

- **Title** — SPACE for level select.
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
| Dark blue with "?" | **hidden layer**: revealed when it reaches the top. A pour stops at it, even if it is the same colour |
| White crystals and a number | **frozen**: can't pour from or into it. The number drops with every move; at 0 it thaws |
| A padlock in a colour | **locked**: opens when a bottle of that colour is completed |
| White bulb on the neck | **dropper**: pours one layer at a time |
| Stripes over the body | **curtain**: you can't see inside until the first pour into or out of it |
| White notches on the walls | **different size**: holds fewer layers (one notch per layer boundary) |
| Thinner layers | **tall bottle**: 5 or 6 layers |
| `LEFT n` in the HUD | **move limit**: at 0 without a solution, U or R |
| `TIME n` in the HUD | **timer**: at 0, R to try again |

Every 10th level is a **Challenge**: several types together and one more colour.

## When you're stuck

When there is no valid move, the HUD shows `NO MOVES!`. Press **U** to go
back, **R** to start over, or **E** for an extra bottle where allowed.

Tips:

- Keep one bottle empty for as long as you can.
- Collect first the colours that are already on top of several bottles.
- With hidden layers, open the bottles with the fewest "?" first.
