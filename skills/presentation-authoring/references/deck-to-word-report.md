# Deck → companion Word report

When the user asks for the talk's text as a Word document ("доклад в
ворде по этой презентации, разбей послайдам"), derive it from the
finished `.pptx` — the deck is the single source of truth for both the
bullets and the notes. Retyping guarantees drift.

## Extract per slide from the .pptx

```python
from pptx import Presentation
EMU = 914400.0
prs = Presentation(deck)
for idx, s in enumerate(prs.slides, 1):
    frames = []
    for sh in s.shapes:
        if not sh.has_text_frame:
            continue
        paras = [" ".join("".join(r.text for r in p.runs).split())
                 for p in sh.text_frame.paragraphs]
        paras = [t for t in paras if t]
        if not paras:
            continue
        frames.append((sh.top / EMU, sh.left / EMU, paras))
    frames.sort(key=lambda x: (x[0], x[1]))
```

Rules for turning frames into bullets:

- **Title by geometry, not string equality.** In a band-layout deck the
  title box is `top < 1.05` and `left < 1.0`; the kicker sits in the same
  band at a larger `left`. Comparing the text to the deck title breaks
  the moment the title is reworded.
- **`top > 6.95` is the footer** — skip it.
- **A frame with >1 non-empty paragraph is a bullet list**; emit each
  paragraph as its own bullet and never let such a frame enter a merge.
- **Single-paragraph frames are captions** (card heading, banner,
  takeaway plate). Merge a short one with the single-paragraph frame
  directly below it only when ALL of these hold: ≤75 chars, no terminal
  `.`/`!`/`?`/`:`/`—`, vertical gap > 0.5", `abs(left) < 0.06`. Mark
  both frames consumed so nothing is reused.
- **Two false-merge patterns to design the tolerance around.** A deck
  subtitle/kicker sits near the first card's left and gets glued onto
  that card's heading ("…три канала доставки программы — DAB / DAB+");
  and a compact table (Год / Событие / Роль) renders as one column of
  single-paragraph frames that pair into nonsense. The `:`/`—` terminal
  filter plus the tight 0.06" left tolerance kills both — a loose
  0.2–0.4" tolerance does not. When a deck uses either pattern and the
  rule still mispairs, drop the merge and emit the frames as-is: a
  slightly choppy bullet list beats a wrong one.
- **Sort by (top, left) before pairing**, or the merge order stops
  matching reading order.
- **Join runs per paragraph**: PowerPoint fragments runs at spell-check
  boundaries, so `p.text` alone can split a word.

## Notes → speech text + timing

Notes carry the `[Хронометраж: ~NN с]` prefix written during authoring;
parse it instead of recounting:

```python
import re
note = s.notes_slide.notes_text_frame.text
m = re.match(r"\[Хронометраж: ~(\d+) с\]\s*", note)
timing = int(m.group(1)) if m else 0
speech = [p.strip() for p in note[m.end():].split("\n") if p.strip()]
```

Keep one paragraph per notes paragraph — the notes are already paced
for their slide.

## Build the docx spec

Two shapes; pick by the brief.

### Minimal (default)

«Доклад по слайдам и ничего лишнего» = headings + speech paragraphs
only. Build with python-docx directly — no title page, no meta line,
no overview table, no timing prefixes, no word count:

```python
from docx import Document
from docx.shared import Pt, Cm

doc = Document()
st = doc.styles["Normal"]
st.font.name = "Times New Roman"; st.font.size = Pt(14)

for slide_title, paragraphs in slides:          # (title, [speech paras])
    doc.add_heading(slide_title, level=2)
    for para in paragraphs:
        p = doc.add_paragraph(para)
        p.paragraph_format.first_line_indent = Cm(1.25)
        p.paragraph_format.space_after = Pt(6)
doc.save(out)
```

### Annotated (opt-in, only when asked)

Use the bundled `docx` skill's `docx_create.py`:

- Title block: deck title, a subtitle line ("Текст доклада для
  выступления (разбит по слайдам)"), and one meta line with the
  reglament plus the summed timing.
- Custom styles per look: `DocTitle` (22 pt bold, brand colour),
  `DocSub`, `DocMeta` (10 pt grey), `Lead` (11 pt bold brand colour —
  used for the "На слайде:" / "Что говорить:" labels), `SlideNote`
  (11.5 pt body).
- A `table` block as the overview: header
  `["№", "Слайд", "Тезисов", "Хронометраж"]`, one row per slide.
- Per slide: `heading` level 2 `Слайд N. <title>`, the timing meta
  paragraph, `Lead` + `bullet_list` for the slide text, `Lead` + one
  paragraph per notes paragraph.
- `header` = deck title + " — текст доклада"; `footer_page_numbers: true`.

Both variants verify the same way:

Then verify:

```bash
python scripts/docx_create.py spec.json out.docx
python scripts/docx_validate.py out.docx
python scripts/docx_read.py out.docx --structure   # outline + counts
python scripts/docx_read.py out.docx --text        # spot-check bullets/speech
```

## PDF preview without LibreOffice

Word COM renders docx, and PowerPoint's `Visible = 0` restriction does
not apply to it:

```python
import os, win32com.client
wd = win32com.client.Dispatch("Word.Application")
wd.Visible = False
doc = wd.Documents.Open(src, ReadOnly=True)
doc.Repaginate()
pages, words = doc.ComputeStatistics(2), doc.ComputeStatistics(0)
doc.ExportAsFixedFormat(os.path.join(outdir, "preview.pdf"),
                        ExportFormat=17)   # 17 = PDF
doc.Close(False)
wd.Quit()
```

On this Word build `ComputeStatistics` maps 0 = words, 2 = pages —
cross-check before trusting another index.

## Pitfalls

- **«Только доклад по слайдам и ничего лишнего» is a deliverable
  spec**, not a summary of it: headings + speech paragraphs, nothing
  else. A title page or timing table in the shipped file is scope the
  user asked to remove.
- **`footer_page_numbers` writes field codes**: `docx_read.py --text`
  shows the literal placeholder ("Page 1 of 1") until Word opens the
  file. Report it as expected, don't "fix" it.
- **Never hand-copy slide text into the report.** Re-run the extractor
  after any deck edit; a retyped report drifts within one revision.
- **`--structure` + `--text` verify content; the PDF preview is for
  layout only** — don't re-render to check that a string exists.
- **Word keeps an owner lock (`~$file.docx`) while a COM document is
  open** — `Close` then `Quit` before rebuilding, or the write fails
  with a locked-file error.
- **A stale `~$Name.pptx` from a PowerPoint render blocks `rm` and
  rebuilds.** Kill `POWERPNT.EXE` first; the lock clears with the
  process, not with the file system.
- **Deliver with `MEDIA:`** and report page/word counts from the COM
  call, not from the paragraph outline.
