---
name: presentation-authoring
description: Use when building a full pptx deck with custom visuals.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [pptx, powerpoint, presentation, slides, speaker-notes, design]
    category: productivity
    related_skills: [powerpoint]
---

# Presentation Authoring

Author a complete deck — slide text, custom visuals, speaker notes, and
time budget — from a user brief. Covers the authoring layer above raw
python-pptx file operations: layout system, self-drawn visuals, note
timing, and visual verification. Use `powerpoint` for create/read/edit
of an existing .pptx via its helper scripts; use this skill when the
deck itself must be designed.

## When to Use

- A brief specifies slide count, per-slide time budget, or "only short
  bullets, no paragraphs" — i.e. the deliverable is a talk, not a doc.
- The deck needs diagrams, charts, or icons and no image assets exist
  (generate them — see `references/pil-slide-visuals.md`).
- Speaker notes must fill an exact time window ("5–8 minutes").
- A finished deck must also ship as a Word report broken down by slide
  ("доклад в ворде по этой презентации") — step 8 below.
- `powerpoint` is bundled and can't hold this workflow; its
  `pptx_create.py` JSON spec is too rigid for a designed layout.

## Prerequisites

`python-pptx` and `pywin32` are usually absent from the default
interpreter. Build an isolated venv once per project directory:

```bash
uv venv .venv-pptx --python 3.11
./.venv-pptx/Scripts/python.exe -m ensurepip          # Windows
./.venv-pptx/Scripts/python.exe -m pip install "python-pptx==1.0.2" "pywin32==311" -q
./.venv-pptx/Scripts/python.exe -m pip install "python-docx==1.1.2" -q   # step 8
```

Run every build/render script with that interpreter, not the bare
`python`. On Linux/macOS use `.venv-pptx/bin/python`.

Faster path when no project venv exists: `uv pip install "python-pptx==1.0.2"
"python-docx==1.1.2" --system` installs into the Hermes-managed Python that
`execute_code`/`terminal` use, so the build script runs with the bare
`python`. Plain `pip install` can succeed against a different
interpreter while `import pptx` still fails — that mismatch is the
failure, not a missing package.

## Procedure

### 1. Fix the constraints before drawing anything

Extract from the brief: slide count, seconds per slide, max bullet
lines per slide. Never render identity placeholders (ФИО, группа,
дисциплина) on the title slide unless the user supplied the values —
a field they have to delete in PowerPoint is worse than an absent one.
Plan the budget: words ≈ seconds × 2.25 for Russian at ~135 words/min,
i.e. ~50 s per content slide is about 110–120 words of spoken text.
When the brief gives both a word count and a time range, compute the
minutes from the words and state both — a 700-word script against an
8-minute floor is a 5-minute talk, and silently shipping it short
breaks the user's reglament.

### 2. Design the layout system first, then the content

Build a chrome function (header band + accent rule + footer + slide
number) and reuse it on every slide — one edit re-skins the deck.
Blank layout (index 6) plus absolute-positioned textboxes gives full
control; default placeholders are 9" wide on a 13.333" 16:9 slide and
leave a dead right margin. Set `prs.slide_width/height` to 13.333×7.5
in the script, not via a spec file.

### 3. Draw the visuals yourself

Never use stock images. Two toolkits, chosen per visual:

- **Native pptx shapes** (rectangles, rounded rectangles, ovals,
  connector arrows, text chips) for card grids, labeled scales,
  waveform bars, signal-chain diagrams, and step flows — they stay
  editable in PowerPoint, need no asset pipeline, and emoji icons
  (📡 💬 🎙 🎧) render directly in text boxes.
- **PIL PNGs** only for visuals shapes can't carry well: log-scale
  frequency bands, multi-signal comparisons, pixel charts. Recipe and
  supersampling wrapper: `references/pil-slide-visuals.md`.

Default visual density: every content slide carries at least one
built visual element — a bullet-only slide reads as unfinished when
the brief asks for «красивое оформление». Verify each asset with
`vision_analyze` before assembling the deck — a mis-drawn icon is
invisible in an XML outline.

### 4. Write notes as spoken text, first person

Each note answers "what do I say while this slide is up", in the
voice the user asked for. Prefix each with `[Хронометраж: ~NN с]`.
Never let notes paraphrase the bullets.

### 5. Measure before you render

Two cheap checks catch nearly all layout bugs without PowerPoint:

- Text overflow: wrap-estimate each block with PIL font metrics and
  compare against its box height.
- Geometry: walk every shape and assert `left/top ≥ 0` and
  `left+width ≤ 13.333`, `top+height ≤ 7.5`.

Both are a few lines each; keep them in the build script so re-runs
re-check. Full recipes: `references/timing-and-verification.md`.

### 6. Render and look

If `soffice`/poppler are missing, use PowerPoint COM:
`scripts/export_pptx_png.py deck.pptx ./render`. Then
`vision_analyze` every rendered slide, asking specifically about
overlap, truncation, and edge-clipping. Fix and re-render.

### 7. Ship the file

Write the deck into the working directory and deliver it with
`MEDIA:/absolute/path.pptx`, plus a compact table of the 9 slides
(number, title, bullets, timing, visual) and the total word count
converted to minutes. Never describe the deck in chat instead of
building it.

### 8. Companion Word report (deck → .docx)

When the user asks for the talk's text as a Word document, extract it
from the finished .pptx rather than retyping — the deck is the single
source of truth for both the bullets and the notes. **Default output is
minimal**: one `heading` "Слайд N. <title>" per slide followed by that
slide's speech paragraphs — no title page, no meta/timing lines, no
overview table, no word count. «Только доклад по слайдам и ничего
лишнего» means exactly that. The annotated variant (title block,
structure table, per-slide timing, «На слайде / Что говорить» labels)
is the opt-in, not the default. Extraction recipe, both docx spec
shapes, and the COM PDF preview:
`references/deck-to-word-report.md`.

## Pitfalls

- **`ppt.Visible = 0` through COM raises** "Hiding the application
  window is not allowed" — set `Visible = 1` and open with
  `WithWindow=False`; the window is suppressed by the presentation, not
  the app.
- **Cyrillic in PIL needs an explicit TTF path**: pass
  `C:/Windows/Fonts/arial.ttf` (or `arialbd.ttf`) to `ImageFont.truetype`;
  the default bitmap font cannot render it.
- **Never estimate text fit by eye.** Russian at 18 pt in a 4.5" column
  wraps far earlier than it looks; compute it.
- **A `build_deck.py` that exits 1 with no traceback is a PowerPoint
  lock, not a script bug.** Kill the app (`MSYS_NO_PATHCONV=1 taskkill
  /F /IM POWERPNT.EXE` — MSYS mangles `/F` into a path without that
  guard), wait a beat, re-run. If the build still fails, run the script
  with `python -u` to capture stderr before touching the code.
  A save that raises `PermissionError` with a full traceback is the
  same lock seen through `prs.save()`; when the user has the deck open
  and can't close it, save under a new filename and say so instead of
  stalling.
- **`write_file` refuses to produce a .pptx/.docx** — it detects the
  binary container and errors rather than corrupt the file. Build
  every Office file through python-pptx/python-docx `save()`, and
  never try to "fix" a deck by rewriting its XML as text.
- **Russian typographic quotes in Python literals terminate strings.**
  A straight `"` nested inside a `"`-quoted string closes it early and
  the linter reports `invalid character '»'` far from the real cause —
  use `«»` for in-text quotes in every Russian string literal.
- **A leftover `~$Name.pptx` that resists `rm`, `del`, and
  `os.remove` is harmless.** The owner file outlives the process handle
  on some Windows/OneDrive setups; it does not block a rebuild or an
  export. Don't spend turns deleting it — note it and move on.
- **`python` is not the venv interpreter.** A build that "works" in the
  agent shell may have used a different python than the one with
  python-pptx — always invoke the venv's python explicitly.
- **Check assets one by one before the deck.** A wrong icon baked into a
  rendered slide costs a full rebuild cycle to notice.
- **Speaker-note word count is the time budget.** Count words in the
  notes, not the slide text — slide text is 20% of what gets spoken.
- **No bibliography slide unless the brief asks for one.** End the deck
  on a conclusion slide; a sources list reads as noise the user will
  delete.
- **No closing courtesy slide.** «Спасибо за внимание», «Готов ответить
  на ваши вопросы» and «Вопросы?» are spoken, never on a slide — a
  courtesy slide is the first thing the user deletes, same as the
  identity placeholders. End on the conclusion slide's content.
- **Rework emphasis inside the fixed slide count.** When asked to
  "focus more on X" or "drop Y", restructure the existing slides and
  their notes — the user keeps the slide frame and the 5–8 min budget.

## Support files

- `references/pil-slide-visuals.md` — generating crisp icons/diagrams/charts as PNG.
- `references/timing-and-verification.md` — note timing math, overflow and bounds checks, COM render.
- `references/deck-to-word-report.md` — companion Word report extracted from the finished deck.
- `scripts/export_pptx_png.py` — LibreOffice-free slide → PNG export.
