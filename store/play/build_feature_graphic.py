"""Google Play feature graphic, 1024×500, black-orange theme.

Recolors the previous blue/white graphic: flat blue shapes become the app
primary orange, the white field becomes near-black, and the flame is the
transparent orange logo. The phone screenshot is kept.
"""

from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(
    "/Users/set/.cursor/projects/Users-set-Desktop-SubconsciousET-Projects-flutter-frontend-of-principles/assets/image-957aaee8-f401-48b1-be40-6efea6742bb9.png"
)
LOGO = ROOT / "assets/images/orange_logo.png"
OUT = Path(__file__).resolve().parent / "feature-graphic.png"

W, H = 1024, 500
ORANGE = (255, 107, 0)  # app primary #FF6B00
ORANGE_HUE = colorsys.rgb_to_hsv(1, ORANGE[1] / 255, 0)[0]
# Flat blue used by the source shapes, mixed with white at the edges.
BLUE = (0, 123, 255)


def phone_mask() -> Image.Image:
    """Outer bezel of the source phone, inset 1px to drop the white fringe."""
    tall = Image.new("L", (W, H + 80), 0)
    ImageDraw.Draw(tall).rounded_rectangle(
        (63, 38, 387, 548),
        radius=36,
        fill=255,
    )
    return tall.crop((0, 0, W, H))


def recolor(r: int, g: int, b: int) -> tuple[int, int, int]:
    sat = max(r, g, b) - min(r, g, b)
    if sat > 18 and b >= r and b >= g and (b - r) > 20:
        # Coverage of #007BFF over white. Edge pixels stay dark orange on black
        # instead of a pale halo.
        coverage = (255 - r) / 255
        pred_g = 255 - (255 - BLUE[1]) * coverage
        if abs(g - pred_g) < 36 and abs(b - 255) < 22:
            a = max(0.0, min(1.0, coverage))
            bg = 7
            return tuple(int(ORANGE[i] * a + bg * (1 - a)) for i in range(3))
        # Accent orbs: rotate blue hue onto the app orange, keep saturation and value.
        _h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        rr, gg, bb = colorsys.hsv_to_rgb(ORANGE_HUE, s, v)
        return (int(rr * 255), int(gg * 255), int(bb * 255))

    lifted = (255 - (r + g + b) / 3) * 0.97 + 7
    if lifted < 42:
        return (int(lifted), int(lifted * 0.90), int(lifted * 0.78))
    v = int(max(0, min(255, lifted)))
    return (v, v, v)


def is_old_flame(r: int, g: int, b: int) -> bool:
    return b > r + 30 and b > 100 and r < 240


def erase_old_flame(src: Image.Image) -> None:
    """Remove the previous blue flame by inpainting from surrounding pixels.

    Painting the hole white left a black rectangle after recolor wherever the
    new transparent logo did not cover the old silhouette.
    """
    px = src.load()
    mask = Image.new("L", (W, H), 0)
    mp = mask.load()
    for y in range(80, 260):
        for x in range(690, 850):
            if is_old_flame(*px[x, y]):
                mp[x, y] = 255

    # Grow slightly so soft flame edges are included.
    mask = mask.filter(ImageFilter.MaxFilter(3))
    mp = mask.load()

    filled = src.copy()
    fp = filled.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y] < 128:
                continue
            # Average nearby non-mask samples (search ring).
            total = [0, 0, 0]
            count = 0
            for rad in (2, 4, 8, 14, 22):
                for dy in range(-rad, rad + 1):
                    for dx in range(-rad, rad + 1):
                        if abs(dx) != rad and abs(dy) != rad:
                            continue
                        nx, ny = x + dx, y + dy
                        if not (0 <= nx < W and 0 <= ny < H):
                            continue
                        if mp[nx, ny] >= 128:
                            continue
                        r, g, b = px[nx, ny]
                        total[0] += r
                        total[1] += g
                        total[2] += b
                        count += 1
                if count:
                    break
            if count:
                fp[x, y] = tuple(v // count for v in total)
            else:
                fp[x, y] = (255, 255, 255)

    src.paste(filled)


def orange_logo(height: int) -> Image.Image:
    """Flame only — knock out any residual near-black so the paste is clear."""
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    width = max(1, round(height * logo.width / logo.height))
    logo = logo.resize((width, height), Image.Resampling.LANCZOS)
    px = logo.load()
    for y in range(logo.height):
        for x in range(logo.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # Soft fringe from resize on transparent black → drop it.
            if max(r, g, b) < 28:
                px[x, y] = (0, 0, 0, 0)
            elif max(r, g, b) < 55 and a < 220:
                px[x, y] = (r, g, b, 0)
    return logo


def main() -> None:
    src = Image.open(SRC).convert("RGB")
    if src.size != (W, H):
        raise SystemExit(f"expected {W}x{H}, got {src.size}")

    erase_old_flame(src)

    out = Image.new("RGB", (W, H))
    spx = src.load()
    opx = out.load()
    for y in range(H):
        for x in range(W):
            opx[x, y] = recolor(*spx[x, y])

    mask = phone_mask()
    out.paste(Image.open(SRC).convert("RGB"), (0, 0), mask)

    logo = orange_logo(168)
    lx = 758 - logo.width // 2
    ly = 165 - logo.height // 2
    out.paste(logo, (lx, ly), logo)

    out.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} {out.size} {OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
