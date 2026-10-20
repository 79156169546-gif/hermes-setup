# PIL slide visuals

Generate icons, diagrams, and charts as PNG with PIL. No stock image
search, no copyright questions, and every asset matches the deck's
palette exactly.

## Supersampling wrapper (mandatory)

PIL's `line`/`rectangle`/`ellipse` have no antialiasing — diagonal lines
and circles look jagged at 1×. Draw at 3–4× and downscale with LANCZOS:

```python
SS = 3

class D:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w*SS, h*SS), (0,0,0,0))
        self.d = ImageDraw.Draw(self.img)
    def s(self, v): return int(round(v*SS))
    def line(self, pts, fill, w=3):
        self.d.line([(self.s(x), self.s(y)) for x, y in pts],
                    fill=fill, width=self.s(w), joint="curve")
    def rrect(self, box, fill=None, outline=None, w=2, r=16):
        self.d.rounded_rectangle([self.s(v) for v in box], radius=self.s(r),
                                 fill=fill, outline=outline, width=self.s(w))
    def text(self, xy, txt, size, fill, bold=True, anchor="mm"):
        f = ImageFont.truetype(ARIALB if bold else ARIAL, self.s(size))
        self.d.text((self.s(xy[0]), self.s(xy[1])), txt, font=f,
                    fill=fill, anchor=anchor)
    def save(self, name):
        self.img.resize((self.w, self.h), Image.LANCZOS).save(f"{OUT}/{name}")
```

All coordinates are in virtual pixels; `anchor` (`mm`, `lm`, `rm`)
centres text without manual offset math.

## Fonts

- Regular: `C:/Windows/Fonts/arial.ttf`
- Bold: `C:/Windows/Fonts/arialbd.ttf`
- Cyrillic requires an explicit TTF path — the default PIL font cannot
  render it and silently produces blanks/tofu.

## Asset shapes that work well

| Slide need | Approach |
|---|---|
| Process / signal chain | Row of rounded-rectangle cards, glyph inside a filled circle, orange `polygon` arrow between them, label under each card |
| Contrast (A vs B) | Two framed panels side by side, same y-scale, one colored signal line each; caption line under each panel |
| Timeline | Horizontal rule + one filled dot per event, year above in the event colour, 2-line caption below |
| Frequency bands | Log-scale x-axis (`math.log10`), one colored rounded bar per band on its own row, range + property caption under the bar |
| Feature cards | Badge PNG (rounded square + white glyph), colored top rule on a light card, heading in the badge colour, body 13–14 pt |

## Log scale for range charts

When values span decades (100 kHz → 100 MHz), linear positions make
narrow bands invisible. Map `log10(f)` onto the axis and label ticks at
decades only (100 kHz, 1 MHz, 10 MHz, 100 MHz). Format with commas:
`f"{f/1e6:.2f} МГц".replace('.', ',')`.

## Badge glyphs

One reusable 360×360 rounded square with a white pictogram covers icons
for any deck. Cheap glyph primitives: `arc` for signal waves, `poly`
for arrows/speakers, `rrect`+`ell` for mic/broadcast, stacked `rrect`
for bar charts. Keep strokes 7–11 virtual px so they survive 3×
downscale.

## Aspect ratio discipline

Export at the aspect ratio of the box it will occupy (e.g. 3100×780 for
a full-width strip), then place with width only — python-pptx scales
height from the image. Placing by height on a wide image squashes it.

## Verify each asset before assembling

`vision_analyze` every generated PNG with a targeted question
(«читаемы ли подписи, нет ли обрезки справа, не накладывается ли
текст»). Two prompts cost less than rebuilding the deck: one asking
what is drawn, one asking about overlap/clipping.

