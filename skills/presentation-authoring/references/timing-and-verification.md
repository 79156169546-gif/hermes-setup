# Timing, overflow checks, and render verification

## Speaker-note timing

The brief's time budget is met by the NOTES, not the slide text. Count
words in the notes and convert:

```python
import re
from pptx import Presentation
prs = Presentation(path)
for i, s in enumerate(prs.slides, 1):
    body = s.notes_slide.notes_text_frame.text.split("\n\n", 1)[1]
    w = len(re.findall(r"[А-Яа-яЁёA-Za-z0-9]+", body))
    print(i, w, f"~{w/135*60:.0f}–{w/150*60:.0f} с")
```

- Russian presentation pace: **135–150 words/min** → seconds ≈ words / 2.25 to 2.5.
- ~50 s of speech is roughly **110–120 words**; ~45 s is ~100.
- State the pace assumption when reporting the total ("6.7–7.4 min at
  135–150 wpm"), never a single number.
- Prefix every note with `[Хронометраж: ~NN с]` so the timing is visible
  while presenting.

## Text overflow estimate

PowerPoint silently shrinks or clips overflowing text. Estimate before
rendering with PIL metrics:

```python
def check(label, items, box_w, box_h, size, space_pt=10, line_sp=1.05):
    fnt = ImageFont.truetype(ARIAL, int(round(size * 96 / 72)))
    maxw = (box_w - 0.30) * 96            # 96 px/inch, minus bullet indent
    total = 0.0
    for it in items:
        txt = "".join(it) if isinstance(it, tuple) else it
        words, lines, cur = txt.split(), 1, 0.0
        sp = fnt.getlength(" ")
        for wd in words:
            wl = fnt.getlength(wd)
            if cur and cur + sp + wl > maxw:
                lines += 1; cur = wl
            else:
                cur += (sp if cur else 0) + wl
        total += lines * size * line_sp * 1.22 / 72 + space_pt / 72
    print(label, round(total, 2), "/", box_h,
          "OK" if total <= box_h else "ПЕРЕПОЛНЕНИЕ")
```

Bold lead-in runs are wider than regular text; keep the ratio under
~0.85 of box height to leave margin.

## Shape bounds check

After saving, re-open the deck and assert nothing leaves the canvas:

```python
for i, s in enumerate(Presentation(path).slides, 1):
    for sh in s.shapes:
        l, t = sh.left/914400, sh.top/914400
        w, h = sh.width/914400, sh.height/914400
        assert l >= 0 and t >= 0 and l+w <= 13.334 and t+h <= 7.51, (i, l, t)
```

Pictures placed with `width=` only are the usual offenders — their
scaled height pushes past the bottom edge.

## Text-box overlap check

Per-box overflow and canvas bounds both pass while two text blocks sit
on top of each other — a caption nudged up onto a banner is the classic
case. Pairwise-intersect every TEXT box and flag pairs whose overlap
exceeds ~35% of the smaller box:

```python
boxes = [(sh.left, sh.top, sh.width, sh.height, sh.text_frame.text[:40])
         for sh in s.shapes
         if sh.has_text_frame and sh.text_frame.text.strip()]
for i in range(len(boxes)):
    for j in range(i + 1, len(boxes)):
        a, b = boxes[i], boxes[j]
        ox = min(a[0]+a[2], b[0]+b[2]) - max(a[0], b[0])
        oy = min(a[1]+a[3], b[1]+b[3]) - max(a[1], b[1])
        if ox > 0 and oy > 0 and ox*oy > 0.35 * min(a[2]*a[3], b[2]*b[3]):
            print(idx, "OVERLAP", a[4], "vs", b[4])
```

Restrict the pairwise check to text boxes only — filled shapes (cards,
bands) legitimately sit under the text boxes they carry, and shape-vs-
text overlap is by design. When the brief says «проверь, не съезжает ли
текст», run both checks and report the result explicitly ("переполнений
и перекрытий не найдено"), not just the individual fixes — the user
asked for the verification, so the clean run is part of the deliverable.

## Render without LibreOffice

See `scripts/export_pptx_png.py`. Requires `pip install pywin32`:

- `ppt.Visible = 0` raises a COM error ("Hiding the application window
  is not allowed"); use `Visible = 1` with `Open(..., WithWindow=False)`.
- `pres.Export(outdir, "PNG", 1600, 900)` writes `Slide1.PNG` …
- Always `pres.Close()` then `ppt.Quit()`, or a stray PowerPoint
  process locks the .pptx.

## Review loop

`vision_analyze` each rendered slide with a question naming the failure
modes you actually care about: overlap between blocks, text past a
card's edge, labels clipped at the right border. A generic "describe
this slide" wastes the pass — ask about geometry.

