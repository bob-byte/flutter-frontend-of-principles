"""Compose App Store screenshots at 1290×2796 (iPhone 6.9" slot).

Source captures are the chat attachments. Re-run after replacing them with
full-resolution exports of the same screens.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(
    "/Users/set/.cursor/projects/Users-set-Desktop-SubconsciousET-Projects-flutter-frontend-of-principles/assets"
)
OUT = Path(__file__).resolve().parent / "iphone-6.9"

W, H = 1290, 2796
TOP = (36, 46, 62)
BOTTOM = (58, 70, 90)
WHITE = (248, 246, 242)
ORANGE = (255, 138, 0)
LABEL = (255, 160, 64)

FONT_BOLD = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD, size, index=1)


def gradient(w: int, h: int) -> Image.Image:
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / (h - 1)
        px[0, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
    return strip.resize((w, h), Image.Resampling.BILINEAR)


def knock_out_black(im: Image.Image, hard: int = 10, soft: int = 28) -> Image.Image:
    im = im.convert("RGBA")
    pix = im.load()
    width, height = im.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pix[x, y]
            peak = max(r, g, b)
            if peak <= hard:
                pix[x, y] = (r, g, b, 0)
            elif peak < soft:
                fade = int(255 * (peak - hard) / (soft - hard))
                pix[x, y] = (r, g, b, min(a, fade))
    return im


def trim_alpha(im: Image.Image, pad: int = 0) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def redact_email(im: Image.Image) -> Image.Image:
    """Replace the real address with a placeholder that matches the row."""
    im = im.convert("RGBA")
    w, h = im.size
    x0, x1 = int(w * 0.16), int(w * 0.78)
    y0, y1 = int(h * 0.268), int(h * 0.298)
    above, below = int(h * 0.262), int(h * 0.304)
    pix = im.load()
    span = max(1, below - above)
    for y in range(y0, y1):
        t = (y - above) / span
        for x in range(x0, x1):
            a = pix[x, above]
            b = pix[x, below]
            pix[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(4))
    face = ImageFont.truetype(FONT_BOLD, max(13, int(h * 0.017)), index=0)
    ImageDraw.Draw(im).text(
        (int(w * 0.186), int(h * 0.271)),
        "you@email.com",
        font=face,
        fill=(186, 186, 186, 255),
    )
    return im


def load_screen(name: str, redact: bool = False) -> Image.Image:
    im = Image.open(SRC / name).convert("RGBA")
    if redact:
        im = redact_email(im)
    return im


def load_widget(name: str) -> Image.Image:
    im = Image.open(SRC / name).convert("RGBA")
    # Home-screen page dots sit on the black margin of some captures.
    pix = im.load()
    width, height = im.size
    for y in range(height):
        for x in range(width):
            if 16 < x < width - 16:
                continue
            r, g, b, _a = pix[x, y]
            if r > 180 and g > 180 and b > 180:
                pix[x, y] = (0, 0, 0, 255)
    # Page-indicator halo on the month capture sits just outside the card.
    if "7134" in name:
        for y in range(860, min(height, 930)):
            for x in range(0, 12):
                pix[x, y] = (0, 0, 0, 255)
    return trim_alpha(knock_out_black(im))


def upscale(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    scaled = im.resize(size, Image.Resampling.LANCZOS)
    return scaled.filter(ImageFilter.UnsharpMask(radius=1.4, percent=60, threshold=2))


def phone_frame(screen: Image.Image, screen_w: int) -> Image.Image:
    aspect = screen.height / screen.width
    screen_h = round(screen_w * aspect)
    screen = upscale(screen, (screen_w, screen_h))
    radius = max(28, round(screen_w * 0.125))
    screen.putalpha(rounded_mask(screen.size, radius))

    bezel = max(14, round(screen_w * 0.018))
    outer = (screen_w + bezel * 2, screen_h + bezel * 2)
    frame = Image.new("RGBA", outer, (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle(
        (0, 0, outer[0] - 1, outer[1] - 1),
        radius=radius + bezel,
        fill=(18, 18, 20, 255),
    )
    draw.rounded_rectangle(
        (2, 2, outer[0] - 3, outer[1] - 3),
        radius=radius + bezel - 2,
        outline=(92, 96, 104, 255),
        width=2,
    )
    frame.paste(screen, (bezel, bezel), screen)
    return frame


def shadow_for(size: tuple[int, int], radius: int) -> Image.Image:
    blur = 36
    canvas = Image.new("RGBA", (size[0] + blur * 4, size[1] + blur * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (blur * 2, blur * 2 + 18, blur * 2 + size[0], blur * 2 + size[1] + 18),
        radius=radius,
        fill=(0, 0, 0, 150),
    )
    return canvas.filter(ImageFilter.GaussianBlur(blur))


def paste(base: Image.Image, overlay: Image.Image, xy: tuple[int, int]) -> None:
    base.paste(overlay, xy, overlay)


def draw_headline(base: Image.Image, lines: list[list[tuple[str, bool]]], y: int) -> int:
    face = font(78)
    draw = ImageDraw.Draw(base)
    max_w = W - 120
    # Shrink until the widest line fits.
    size = 78
    while size > 48:
        face = font(size)
        widest = 0
        for spans in lines:
            widest = max(widest, sum(draw.textlength(text, font=face) for text, _ in spans))
        if widest <= max_w:
            break
        size -= 2
    gap = int(size * 1.18)
    for spans in lines:
        total = sum(draw.textlength(text, font=face) for text, _ in spans)
        x = (W - total) / 2
        for text, accent in spans:
            fill = ORANGE if accent else WHITE
            draw.text((x, y), text, font=face, fill=fill)
            x += draw.textlength(text, font=face)
        y += gap
    return y


def glow(base: Image.Image, box: tuple[int, int, int, int], alpha: int = 46) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=(255, 120, 20, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(70))
    base.paste(layer, (0, 0), layer)


def screen_slide(filename: str, lines: list[list[tuple[str, bool]]], shot: str, redact: bool = False) -> None:
    base = gradient(W, H).convert("RGBA")
    y = draw_headline(base, lines, 168)
    screen = load_screen(shot, redact=redact)
    # Leave room under the headline and a bottom margin.
    top = y + 56
    bottom_margin = 72
    avail_h = H - top - bottom_margin
    # Bezel adds ~3.6% to height.
    screen_w = int(min(1040, (avail_h / 1.045) * (screen.width / screen.height)))
    frame = phone_frame(screen, screen_w)
    glow(
        base,
        (
            (W - frame.width) // 2 - 40,
            top + 80,
            (W + frame.width) // 2 + 40,
            top + frame.height - 40,
        ),
    )
    shade = shadow_for(frame.size, radius=80)
    sx = (W - shade.width) // 2
    sy = top - 36
    paste(base, shade, (sx, sy))
    paste(base, frame, ((W - frame.width) // 2, top))
    base.convert("RGB").save(OUT / filename, "PNG", optimize=True)
    print(filename, base.size)


def fit_width(im: Image.Image, width: int) -> Image.Image:
    height = max(1, round(im.height * width / im.width))
    return upscale(im, (width, height))


def widget_slide() -> None:
    base = gradient(W, H).convert("RGBA")
    y = draw_headline(
        base,
        [
            [("Habits and tasks", False)],
            [("on your Home Screen", True)],
        ],
        150,
    )
    today = load_widget("IMG_7132-17b04080-6e48-42cf-9e48-2e8cb3996e8f.png")
    week = load_widget("IMG_7133-ee0d92ad-99e1-4fb9-ba0d-0ab1f274b6cb.png")
    month = load_widget("IMG_7134-34104422-f690-4e0d-a64b-d2b2065ab500.png")

    content_w = 1140
    gap = 28
    label_h = 44
    # Provisional heights at full content width, then scale the stack to fit.
    specs = [
        ("Today", today, int(content_w * 0.46)),
        ("This week", week, content_w),
        ("This month", month, content_w),
    ]
    fitted = [(label, fit_width(im, width)) for label, im, width in specs]
    stack_h = sum(label_h + im.height for _, im in fitted) + gap * (len(fitted) - 1)
    avail = H - (y + 36) - 64
    if stack_h > avail:
        scale = avail / stack_h
        fitted = [
            (label, fit_width(src, max(1, int(im.width * scale))))
            for (label, src, _), (_, im) in zip(specs, fitted)
        ]
        stack_h = sum(label_h + im.height for _, im in fitted) + gap * (len(fitted) - 1)

    y += 36
    # Center the block in the remaining canvas.
    extra = max(0, avail - stack_h) // 2
    y += extra
    label_font = font(32)
    draw = ImageDraw.Draw(base)
    for label, im in fitted:
        x = (W - im.width) // 2
        draw.text((x, y), label, font=label_font, fill=LABEL)
        y += label_h
        shade = shadow_for(im.size, radius=36)
        paste(base, shade, (x - (shade.width - im.width) // 2, y - 28))
        paste(base, im, (x, y))
        y += im.height + gap

    base.convert("RGB").save(OUT / "07-home-widgets.png", "PNG", optimize=True)
    print("07-home-widgets.png", base.size)


INK = (255, 255, 255, 255)
MUTED = (198, 206, 218)
CARD = (255, 255, 255, 28)
CARD_EDGE = (255, 255, 255, 42)


def _icon(bg: tuple[int, int, int], paint) -> Image.Image:
    size = 100
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    draw.ellipse((0, 0, size - 1, size - 1), fill=bg + (255,))
    paint(draw, size, bg)
    return im


def _star(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    cx = cy = s / 2
    outer, inner = s * 0.34, s * 0.14
    points = []
    for i in range(8):
        radius = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / 4
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    draw.polygon(points, fill=INK)


def _chat(draw: ImageDraw.ImageDraw, s: int, bg: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((s * 0.18, s * 0.20, s * 0.82, s * 0.64), radius=12, fill=INK)
    draw.polygon(
        [(s * 0.30, s * 0.58), (s * 0.26, s * 0.80), (s * 0.50, s * 0.58)],
        fill=INK,
    )
    for x in (0.34, 0.46, 0.58):
        draw.ellipse((s * x, s * 0.36, s * x + s * 0.08, s * 0.44), fill=bg + (255,))


def _checklist(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    for y in (0.26, 0.44, 0.62):
        draw.rounded_rectangle((s * 0.22, s * y, s * 0.38, s * y + s * 0.14), radius=4, fill=INK)
        draw.rounded_rectangle(
            (s * 0.46, s * y + s * 0.04, s * 0.78, s * y + s * 0.11),
            radius=3,
            fill=INK,
        )


def _flag(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((s * 0.30, s * 0.20, s * 0.38, s * 0.80), radius=3, fill=INK)
    draw.polygon(
        [(s * 0.38, s * 0.22), (s * 0.74, s * 0.38), (s * 0.38, s * 0.54)],
        fill=INK,
    )


def _bars(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((s * 0.22, s * 0.52, s * 0.38, s * 0.78), radius=4, fill=INK)
    draw.rounded_rectangle((s * 0.42, s * 0.36, s * 0.58, s * 0.78), radius=4, fill=INK)
    draw.rounded_rectangle((s * 0.62, s * 0.22, s * 0.78, s * 0.78), radius=4, fill=INK)


def _calendar(draw: ImageDraw.ImageDraw, s: int, bg: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((s * 0.20, s * 0.28, s * 0.80, s * 0.80), radius=10, fill=INK)
    draw.rectangle((s * 0.20, s * 0.28, s * 0.80, s * 0.42), fill=INK)
    draw.rounded_rectangle((s * 0.32, s * 0.18, s * 0.40, s * 0.36), radius=3, fill=INK)
    draw.rounded_rectangle((s * 0.60, s * 0.18, s * 0.68, s * 0.36), radius=3, fill=INK)
    for row, y in enumerate((0.50, 0.64)):
        for col, x in enumerate((0.32, 0.46, 0.60)):
            if row == 1 and col == 2:
                continue
            draw.ellipse((s * x, s * y, s * x + s * 0.08, s * y + s * 0.08), fill=bg + (255,))


def _bell(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    draw.ellipse((s * 0.44, s * 0.12, s * 0.56, s * 0.24), fill=INK)
    draw.pieslice((s * 0.22, s * 0.18, s * 0.78, s * 0.72), 180, 360, fill=INK)
    draw.rounded_rectangle((s * 0.18, s * 0.58, s * 0.82, s * 0.70), radius=5, fill=INK)
    draw.ellipse((s * 0.42, s * 0.70, s * 0.58, s * 0.86), fill=INK)


def _target(draw: ImageDraw.ImageDraw, s: int, _bg: tuple[int, int, int]) -> None:
    draw.ellipse((s * 0.18, s * 0.18, s * 0.82, s * 0.82), outline=INK, width=6)
    draw.ellipse((s * 0.32, s * 0.32, s * 0.68, s * 0.68), outline=INK, width=6)
    draw.ellipse((s * 0.44, s * 0.44, s * 0.56, s * 0.56), fill=INK)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if draw.textlength(trial, font=face) <= max_w:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def _header(base: Image.Image, title: str, subtitle: str) -> int:
    draw = ImageDraw.Draw(base)
    title_font = font(96)
    sub_font = font(40)
    y = 150
    draw.text(((W - draw.textlength(title, font=title_font)) / 2, y), title, font=title_font, fill=WHITE)
    y += 118
    draw.text(
        ((W - draw.textlength(subtitle, font=sub_font)) / 2, y),
        subtitle,
        font=sub_font,
        fill=ORANGE,
    )
    return y + 78


def feature_slide() -> None:
    base = gradient(W, H).convert("RGBA")
    glow(base, (180, 80, W - 180, 520), alpha=36)
    y = _header(base, "Features", "Tasks, progress, and Home Screen widgets")
    items = [
        ((47, 128, 237), _star, "AI habit recommender", "Suggestions built around the goal you choose"),
        ((232, 84, 74), _chat, "AI Helper", "A chat that knows your mission, motto, and goals"),
        ((255, 138, 0), _checklist, "Today", "Habits and one-off tasks in one list"),
        ((46, 184, 110), _flag, "Goals", "Habits grouped under the goal they serve"),
        ((155, 89, 182), _bars, "Progress", "Weekly chart, streaks, and a completion calendar"),
        ((22, 160, 176), _calendar, "Home Screen widgets", "Today, this week, and the whole month"),
        ((214, 140, 16), _bell, "Reminders", "A daily check-in, plus alerts until you follow through"),
        ((88, 101, 242), _target, "Mission and slogan", "They decide which habits are worth recommending"),
    ]
    margin = 72
    gap = 16
    avail = H - y - 72
    card_h = (avail - gap * (len(items) - 1)) // len(items)
    card_w = W - margin * 2
    title_font = font(40)
    body_font = font(30)
    text_w = card_w - 56 - 100 - 28
    draw = ImageDraw.Draw(base)
    for bg, painter, title, body in items:
        card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
        card_draw = ImageDraw.Draw(card)
        card_draw.rounded_rectangle((0, 0, card_w - 1, card_h - 1), radius=28, fill=CARD)
        card_draw.rounded_rectangle((1, 1, card_w - 2, card_h - 2), radius=27, outline=CARD_EDGE, width=2)
        icon = _icon(bg, painter)
        card.paste(icon, (28, (card_h - icon.height) // 2), icon)
        lines = [title, *wrap_text(draw, body, body_font, text_w)]
        block_h = 48 + 8 + 36 * (len(lines) - 1)
        text_y = (card_h - block_h) // 2
        text_x = 28 + 100 + 24
        card_draw.text((text_x, text_y), title, font=title_font, fill=WHITE)
        text_y += 50
        for line in lines[1:]:
            card_draw.text((text_x, text_y), line, font=body_font, fill=MUTED)
            text_y += 36
        paste(base, card, (margin, y))
        y += card_h + gap
    base.convert("RGB").save(OUT / "08-features.png", "PNG", optimize=True)
    print("08-features.png", base.size)


def benefit_slide() -> None:
    base = gradient(W, H).convert("RGBA")
    glow(base, (200, 900, W - 200, 2300), alpha=32)
    y = _header(base, "Benefits", "What changes when you keep showing up")
    items = [
        ("Fix your day", "Open the app and know what matters today"),
        ("Build the good habit", "And let the one that holds you back fade"),
        ("Stay consistent", "Repeats you can see, not just intend"),
        ("Reach the goal", "Every habit is tied to an outcome"),
        ("Improve what is lagging", "Your mission points at the gap"),
        ("Keep your word", "Follow-through is what builds confidence"),
        ("Trust the progress", "The calendar shows the days you showed up"),
        ("Keep the week in sight", "Habits and tasks stay on the Home Screen"),
    ]
    margin = 72
    gap = 18
    avail = H - y - 72
    card_h = (avail - gap * (len(items) - 1)) // len(items)
    card_w = W - margin * 2
    num_font = font(42)
    title_font = font(42)
    body_font = font(30)
    draw = ImageDraw.Draw(base)
    for index, (title, body) in enumerate(items, start=1):
        card = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
        card_draw = ImageDraw.Draw(card)
        card_draw.rounded_rectangle((0, 0, card_w - 1, card_h - 1), radius=28, fill=CARD)
        card_draw.rounded_rectangle((0, 18, 8, card_h - 18), radius=4, fill=ORANGE + (255,))
        number = f"{index:02d}"
        num_w = card_draw.textlength(number, font=num_font)
        num_x = 40
        title_x = num_x + num_w + 28
        lines = wrap_text(draw, body, body_font, card_w - title_x - 36)
        block_h = 50 + 6 + 36 * len(lines)
        text_y = (card_h - block_h) // 2
        card_draw.text((num_x, text_y + 2), number, font=num_font, fill=ORANGE)
        card_draw.text((title_x, text_y), title, font=title_font, fill=WHITE)
        line_y = text_y + 52
        for line in lines:
            card_draw.text((title_x, line_y), line, font=body_font, fill=MUTED)
            line_y += 36
        paste(base, card, (margin, y))
        y += card_h + gap
    base.convert("RGB").save(OUT / "09-benefits.png", "PNG", optimize=True)
    print("09-benefits.png", base.size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    screen_slide(
        "01-today.png",
        [
            [("Fix your day", False)],
            [("Habits and tasks, together", True)],
        ],
        "IMG_7127-5b21809d-b477-40a1-9c67-b163b245d51f.jpg",
    )
    screen_slide(
        "02-habits.png",
        [
            [("Track every habit", False)],
            [("and see your progress", True)],
        ],
        "IMG_7122-71ce5da1-f578-40d8-a2bd-f9acba3b8536.png",
    )
    screen_slide(
        "03-habit-detail.png",
        [
            [("See the days you showed up", False)],
            [("week by week", True)],
        ],
        "IMG_7121-ef6d71bf-4326-414b-b0ac-c3165329f15a.png",
    )
    screen_slide(
        "04-ai-habits.png",
        [
            [("Generate habits with AI", False)],
            [("for the goal you choose", True)],
        ],
        "IMG_7126-5f934d9a-066b-40ca-8a18-8a4a5132db8e.png",
    )
    screen_slide(
        "05-mission.png",
        [
            [("Make habits more relevant", False)],
            [("with your mission", True)],
        ],
        "IMG_7128-21a5cf8b-1d56-4f82-9766-fd98402a6988.jpg",
        redact=True,
    )
    screen_slide(
        "06-ai-helper.png",
        [
            [("Get a response", False)],
            [("from AI Helper", True)],
        ],
        "IMG_7123-c3e5a49c-99bd-4a53-b239-8ae150a0e567.png",
    )
    widget_slide()
    feature_slide()
    benefit_slide()


if __name__ == "__main__":
    main()
