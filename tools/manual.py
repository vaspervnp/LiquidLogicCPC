"""Εικόνες και PDF των εγχειριδίων.

    python3 tools/manual.py shots   # docs/imgs/*.png από τον headless CPC
    python3 tools/manual.py pdf     # docs/manual-el.pdf, docs/manual-en.pdf
    python3 tools/manual.py         # και τα δύο

Οι εικόνες παίζονται σαν παίκτης με τα πλήκτρα (όπως το tools/headless.py).
Το PDF: markdown -> HTML (με CSS για A4) -> LibreOffice χωρίς παράθυρο.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import headless as h  # noqa: E402
import levels  # noqa: E402
from cpc import KEY_DOWN, KEY_RIGHT, KEY_SPACE  # noqa: E402

DOCS = os.path.join(h.ROOT, "docs")
IMGS = os.path.join(DOCS, "imgs")


def shots():
    os.makedirs(IMGS, exist_ok=True)
    sym = h.symbols(h.SYM)
    levs = levels.levels()
    loading = []
    c = h.boot(shots=loading)
    g = h.Game(c, sym)

    def save(name):
        h.frame_image(c).save(os.path.join(IMGS, name))

    max(loading[:-1], key=lambda im: len(im.getcolors(1 << 16))).save(os.path.join(IMGS, "loading.png"))
    save("title.png")

    # πίστες 1-3 (για αστέρια, στατιστικά, μετάλλιο)
    g.key(KEY_SPACE)
    c.run_frames(25)
    g.key(KEY_SPACE)
    c.run_frames(30)
    lv = levs[0]
    g.select(lv["solution"][0][0])          # επιλεγμένη πηγή
    c.run_frames(5)
    save("select_source.png")
    g.key(KEY_SPACE)
    for i, j, _ in lv["solution"][:3]:
        g.pour(i, j)
    i, j, _ = lv["solution"][3]             # μια μετάγγιση στη μέση
    g.select(i)
    g.goto(j)
    c.tap_key(KEY_SPACE, hold_frames=1, gap_frames=0)
    for _ in range(400):
        c.run_frames(1)
        if g.peek("pour_phase") == 1 and g.peek("p_alive") > 20:
            break
    save("pour.png")
    for _ in range(400):
        if g.peek("state") != h.ST_POUR:
            break
        c.run_frames(1)
    for i, j, _ in lv["solution"][4:]:
        g.pour(i, j)
    c.run_frames(30)
    save("win.png")
    for k in (1, 2):
        g.load_level(k)
        g.play(levs[k], f"πίστα {k + 1}")
    c.write_ram(sym["save_dirty"], b"\0")
    g.key(ord("m"))
    c.run_frames(40)
    save("select.png")

    # κάρτα και ειδικά μπουκάλια (πίστα 100: πάγος, λουκέτο, σταγονόμετρο...)
    c.write_ram(sym["unlocked"], bytes([100]))
    g.key(KEY_SPACE)                        # στην πίστα 3, και από εκεί στην 100
    c.run_frames(30)
    c.write_ram(sym["level"], bytes([99]))
    g.key(ord("r"))
    c.run_frames(30)
    save("card.png")
    while g.peek("mode") == h.MODE_CARD:
        g.key(KEY_SPACE)
        c.run_frames(30)
    for i, j, _ in levs[99]["solution"][:3]:
        g.pour(i, j)
    c.run_frames(10)
    save("specials.png")

    # οθόνες του τίτλου
    h.to_title(g)
    for key, name, extra in (("o", "options.png", None), ("h", "help.png", None),
                             ("s", "stats.png", KEY_RIGHT)):
        c.write_ram(sym["save_dirty"], b"\0")     # (χωρίς αποθήκευση στη μέση)
        g.key(ord(key))
        c.run_frames(20)
        if extra:
            g.key(extra)
            c.run_frames(5)
        save(name)
        g.key(0x03)
        c.run_frames(20)
    g.key(ord("d"))
    c.run_frames(20)
    for k in "2026":
        g.key(ord(k))
    c.run_frames(10)
    save("seed.png")
    g.key(KEY_SPACE)
    c.run_frames(40)
    lay = g.layers()
    sol = levels.solve(tuple(levels.bottle(4, x) for x in lay)) or []
    for i, j, *_ in sol[:4]:
        g.pour(i, j)
    c.run_frames(10)
    save("relax.png")

    # το τέλος: νίκη στην πίστα 100 και SPACE
    h.to_title(g)
    g.key(KEY_SPACE)
    c.run_frames(25)
    g.key(KEY_SPACE)
    c.run_frames(30)
    for k, v in (("save_dirty", 0), ("level", 99), ("state", h.ST_WIN), ("relax", 0), ("timer_on", 0),
                 ("theme_open", 1)):
        c.write_ram(sym[k], bytes([v]))
    g.key(KEY_SPACE)
    c.run_frames(130)
    save("ending.png")
    # θέμα NEON (ξεκλειδωμένο από το τέλος)
    g.key(KEY_SPACE)
    c.run_frames(20)
    g.key(ord("o"))
    c.run_frames(20)
    for _ in range(3):
        g.key(KEY_DOWN)
    g.key(KEY_SPACE)
    c.run_frames(5)
    c.write_ram(sym["save_dirty"], b"\0")
    g.key(0x03)
    c.run_frames(20)
    save("neon.png")
    print(f"{IMGS}: {len(os.listdir(IMGS))} εικόνες, {g.fails} αποτυχίες")
    return g.fails


CSS = """
@page { size: A4; margin: 18mm 18mm 18mm 18mm; }
body { font-family: 'Noto Sans', 'DejaVu Sans', sans-serif; font-size: 10.5pt;
       line-height: 1.4; color: #222; }
h1 { font-size: 22pt; color: #6a1b6a; border-bottom: 2px solid #6a1b6a;
     padding-bottom: 4pt; margin-bottom: 2pt; }
h2 { font-size: 15pt; color: #6a1b6a; margin-top: 16pt; }
h3 { font-size: 12pt; color: #333; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0; }
th, td { border: 1px solid #bbb; padding: 3pt 6pt; vertical-align: top; }
th { background: #eee0ee; }
code { font-family: 'DejaVu Sans Mono', monospace; font-size: 9.5pt; }
pre { background: #f2f2f2; padding: 6pt; }
p.img { text-align: center; margin: 8pt 0; }
table.figs, table.figs td { border: none; padding: 0 4pt; text-align: center; }
table.figs td { width: 50%; }
p.cap { margin: 2pt 0 8pt 0; font-size: 9pt; }
em { color: #555; }
"""


def figures(body):
    """Εικόνα + λεζάντα (<p><img></p><p><em></em></p>): οι συνεχόμενες ανά δύο
    σε πίνακα, δίπλα-δίπλα. Μέγεθος με width και height στο <img> (το
    LibreOffice δεν κοιτάει το CSS, ούτε μόνο το width)."""
    fig = re.compile(r'<p><img alt="[^"]*" src="([^"]+)" /></p>\s*<p><em>(.*?)</em></p>')
    group = re.compile(r'(?:' + fig.pattern + r'\s*)+')

    def cell(m):
        return f'<td align="center"><img src="{m.group(1)}" width="300" height="218" /><p class="cap" align="center"><em>{m.group(2)}</em></p></td>'

    def table(m):
        cells = [cell(f) for f in fig.finditer(m.group(0))]
        if len(cells) == 1:
            f = fig.search(m.group(0))
            return f'<p class="img" align="center"><img src="{f.group(1)}" width="420" height="305" /></p><p class="cap" align="center"><em>{f.group(2)}</em></p>\n'
        rows = ["<tr>" + "".join(cells[i:i + 2]) + "</tr>" for i in range(0, len(cells), 2)]
        return '<table class="figs">' + "".join(rows) + "</table>\n"

    return group.sub(table, body)


def pdf():
    import markdown
    for lang in ("el", "en"):
        src = os.path.join(DOCS, f"manual-{lang}.md")
        with open(src, encoding="utf-8") as f:
            md = f.read()
        body = markdown.markdown(md, extensions=["tables", "fenced_code"])
        body = figures(body)
        tmp = tempfile.mkdtemp()
        html = os.path.join(tmp, f"manual-{lang}.html")
        with open(html, "w", encoding="utf-8") as f:
            f.write(f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
                    f"<style>{CSS}</style></head><body>{body}</body></html>")
        shutil.copytree(IMGS, os.path.join(tmp, "imgs"))
        subprocess.run(["libreoffice", "--headless", "--convert-to", "pdf:writer_web_pdf_Export",
                        "--outdir", tmp, html], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        shutil.copy(os.path.join(tmp, f"manual-{lang}.pdf"), os.path.join(DOCS, f"manual-{lang}.pdf"))
        shutil.rmtree(tmp)
        print(os.path.join(DOCS, f"manual-{lang}.pdf"))


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    fails = 0
    if what in ("shots", "all"):
        fails = shots()
    if what in ("pdf", "all"):
        pdf()
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
