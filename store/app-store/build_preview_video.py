"""Generate App Store Preview Video for Principles (Flutter rewrite).

Strictly complies with Apple App Store Preview specifications for 6.9" display:
- Dimensions: 886 x 1920 (portrait, progressive)
- Framerate: 30 fps
- Codec: H.264 High Profile Level 4.0, target bitrate 11 Mbps (10-12 Mbps range)
- Audio: Stereo 2-channel (L/R), AAC 256 kbps, 44.1 kHz
- Duration: 22.0 seconds (15-30s allowed)
- Key Poster Frame at 00:00:05.000 (Today view celebration & progress)
"""

from __future__ import annotations

import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import wave

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(
    "/Users/set/.cursor/projects/Users-set-Desktop-SubconsciousET-Projects-flutter-frontend-of-principles/assets"
)
OUT_DIR = Path(__file__).resolve().parent

W, H = 886, 1920
FPS = 30
DURATION_SEC = 22.0
TOTAL_FRAMES = int(FPS * DURATION_SEC)  # 660 frames

# Theme colors matching Flutter app
TOP = (36, 46, 62)
BOTTOM = (58, 70, 90)
WHITE = (248, 246, 242)
ORANGE = (255, 138, 0)
GOLD = (251, 191, 36)
LABEL = (255, 160, 64)

FONT_FILE = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size: int, index: int = 1) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_FILE, size, index=index)


def create_base_gradient() -> Image.Image:
    strip = Image.new("RGB", (1, H))
    px = strip.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
    return strip.resize((W, H), Image.Resampling.BILINEAR)


def phone_frame(screen: Image.Image, screen_w: int = 684) -> Image.Image:
    aspect = screen.height / screen.width
    screen_h = round(screen_w * aspect)
    screen = screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    screen = screen.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))

    radius = max(24, round(screen_w * 0.125))
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen.width - 1, screen.height - 1), radius=radius, fill=255
    )
    screen = screen.convert("RGBA")
    screen.putalpha(mask)

    bezel = max(12, round(screen_w * 0.018))
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


def make_shadow(size: tuple[int, int], radius: int = 40, blur: int = 28) -> Image.Image:
    canvas = Image.new("RGBA", (size[0] + blur * 4, size[1] + blur * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (blur * 2, blur * 2 + 14, blur * 2 + size[0], blur * 2 + size[1] + 14),
        radius=radius,
        fill=(0, 0, 0, 160),
    )
    return canvas.filter(ImageFilter.GaussianBlur(blur))


def draw_headline(
    base: Image.Image,
    line1: str,
    line2: str,
    y: int = 105,
    size: int = 54,
    opacity: float = 1.0,
) -> None:
    if opacity <= 0:
        return
    draw = ImageDraw.Draw(base)
    f = font(size, index=1)
    w1 = draw.textlength(line1, font=f)
    w2 = draw.textlength(line2, font=f)

    c1 = (WHITE[0], WHITE[1], WHITE[2], int(255 * opacity))
    c2 = (ORANGE[0], ORANGE[1], ORANGE[2], int(255 * opacity))

    draw.text(((W - w1) / 2, y), line1, font=f, fill=c1)
    draw.text(((W - w2) / 2, y + int(size * 1.25)), line2, font=f, fill=c2)


def generate_audio_track(output_wav: Path) -> None:
    """Synthesize complete stereo audio track with app sound effects."""
    sr = 44100
    total_samples = int(sr * DURATION_SEC)
    buf_l = [0.0] * total_samples
    buf_r = [0.0] * total_samples

    # 1. Opening splash intro sound
    epic_file = ROOT / "assets/splash/epic_start.wav"
    if epic_file.exists():
        with wave.open(str(epic_file), "rb") as w:
            n_ch = w.getnchannels()
            n_frames = w.getnframes()
            raw = w.readframes(n_frames)
            samples = struct.unpack(f"<{n_frames * n_ch}h", raw)
            for i in range(min(n_frames, total_samples)):
                if n_ch == 2:
                    buf_l[i] += (samples[i * 2] / 32768.0) * 0.85
                    buf_r[i] += (samples[i * 2 + 1] / 32768.0) * 0.85
                else:
                    s = (samples[i] / 32768.0) * 0.85
                    buf_l[i] += s
                    buf_r[i] += s

    # 2. In-app completion chime at t=4.5s
    complete_file = ROOT / "assets/sounds/complete.wav"
    if complete_file.exists():
        complete_start = int(4.5 * sr)
        with wave.open(str(complete_file), "rb") as w:
            n_ch = w.getnchannels()
            n_frames = w.getnframes()
            raw = w.readframes(n_frames)
            samples = struct.unpack(f"<{n_frames * n_ch}h", raw)
            for i in range(n_frames):
                idx = complete_start + i
                if idx >= total_samples:
                    break
                s = (samples[i] / 32768.0) * 1.05
                buf_l[idx] += s * 0.95
                buf_r[idx] += s * 0.85

    # 3. Ambient melodic pad chords
    chords = [
        (2.0, 7.5, [174.61, 220.0, 261.63, 329.63]),
        (7.5, 11.5, [130.81, 196.0, 261.63, 329.63]),
        (11.5, 15.5, [146.83, 220.0, 293.66, 349.23]),
        (15.5, 19.0, [116.54, 174.61, 233.08, 293.66]),
        (19.0, 22.0, [174.61, 220.0, 261.63, 349.23]),
    ]

    for t_start, t_end, freqs in chords:
        s_start = int(t_start * sr)
        s_end = int(t_end * sr)
        dur = t_end - t_start
        for i in range(s_start, min(s_end, total_samples)):
            t = (i - s_start) / sr
            env = 1.0
            attack = 0.5
            decay = 0.5
            if t < attack:
                env = math.sin((t / attack) * (math.pi / 2))
            elif t > dur - decay:
                env = math.sin(max(0.0, (dur - t) / decay) * (math.pi / 2))

            global_t = i / sr
            if global_t > 20.0:
                env *= max(0.0, (22.0 - global_t) / 2.0)

            sample_l = 0.0
            sample_r = 0.0
            for f_idx, f in enumerate(freqs):
                phase1 = 2 * math.pi * f * t
                phase2 = 2 * math.pi * (f * 1.002) * t
                phase3 = 2 * math.pi * (f * 0.998) * t
                harm = 2 * math.pi * (f * 2) * t
                val = (
                    math.sin(phase1) * 0.5
                    + math.sin(phase2) * 0.25
                    + math.sin(phase3) * 0.25
                    + math.sin(harm) * 0.08
                )
                pan = 0.3 + 0.4 * (f_idx / max(1, len(freqs) - 1))
                sample_l += val * (1.0 - pan)
                sample_r += val * pan

            buf_l[i] += sample_l * env * 0.085
            buf_r[i] += sample_r * env * 0.085

    # 4. Cinematic scene transition whooshes
    transitions = [2.2, 7.5, 11.5, 15.5, 18.8]
    for trans_t in transitions:
        trans_s = int((trans_t - 0.2) * sr)
        whoosh_len = int(0.7 * sr)
        for j in range(whoosh_len):
            idx = trans_s + j
            if 0 <= idx < total_samples:
                tj = j / sr
                freq = 350 + 800 * math.sin(tj / 0.7 * math.pi)
                phase = 2 * math.pi * freq * tj
                env = (math.sin(tj / 0.7 * math.pi) ** 2) * 0.06
                pan = tj / 0.7
                val = math.sin(phase) * env
                buf_l[idx] += val * (1.0 - pan)
                buf_r[idx] += val * pan

    # Encode to 16-bit PCM wav
    out_frames = bytearray()
    for i in range(total_samples):
        vl = max(-0.98, min(0.98, buf_l[i]))
        vr = max(-0.98, min(0.98, buf_r[i]))
        il = int(vl * 32767)
        ir = int(vr * 32767)
        out_frames.extend(struct.pack("<hh", il, ir))

    with wave.open(str(output_wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(out_frames)
    print(f"Generated soundtrack: {output_wav}")


def prepare_scene_base_images() -> dict[str, Image.Image]:
    """Pre-render and cache base visuals for each scene."""
    cache = {}

    # 1. Intro Screen
    intro = create_base_gradient().convert("RGBA")
    glow = Image.new("RGBA", (500, 500), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((50, 50, 450, 450), fill=(255, 138, 0, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(80))
    intro.paste(glow, ((W - 500) // 2, 650), glow)

    logo = Image.open(ROOT / "assets/images/orange_logo.png").convert("RGBA")
    logo = logo.resize((320, 320), Image.Resampling.LANCZOS)
    intro.paste(logo, ((W - 320) // 2, 720), logo)

    draw_intro = ImageDraw.Draw(intro)
    f_title = font(68, index=1)
    f_tag = font(42, index=1)
    f_sub = font(28, index=0)

    t1 = "PRINCIPLES"
    t2 = "Habits for Goals"
    t3 = "Automate your daily progress"

    draw_intro.text(
        ((W - draw_intro.textlength(t1, font=f_title)) // 2, 1100),
        t1,
        font=f_title,
        fill=WHITE,
    )
    draw_intro.text(
        ((W - draw_intro.textlength(t2, font=f_tag)) // 2, 1185),
        t2,
        font=f_tag,
        fill=ORANGE,
    )
    draw_intro.text(
        ((W - draw_intro.textlength(t3, font=f_sub)) // 2, 1260),
        t3,
        font=f_sub,
        fill=(200, 208, 220, 240),
    )
    cache["intro"] = intro

    # Helper to build a framed slide
    def make_slide(raw_img: Image.Image, l1: str, l2: str) -> Image.Image:
        phone = phone_frame(raw_img, 684)
        base = create_base_gradient().convert("RGBA")
        sh = make_shadow(phone.size)
        fx = (W - phone.width) // 2
        fy = 280
        base.paste(sh, (fx - 56, fy - 56), sh)
        base.paste(phone, (fx, fy), phone)
        draw_headline(base, l1, l2)
        return base

    # 2A. Today initial (uncompleted)
    today_raw_0 = Image.open(
        SRC / "IMG_7127-5b21809d-b477-40a1-9c67-b163b245d51f.jpg"
    ).convert("RGBA")
    cache["today_0"] = make_slide(
        today_raw_0, "Fix your day", "Habits and tasks, together"
    )

    # 2B. Today completed state (checked + updated progress)
    today_raw_1 = today_raw_0.copy()
    pix = today_raw_1.load()
    above, below = 230, 255
    span = below - above
    for y in range(233, 254):
        t = (y - above) / span
        for x in range(43, 206):
            a = pix[x, above]
            b = pix[x, below]
            pix[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(4))

    above_p, below_p = 162, 188
    span_p = below_p - above_p
    for y in range(165, 186):
        t = (y - above_p) / span_p
        for x in range(375, 436):
            a = pix[x, above_p]
            b = pix[x, below_p]
            pix[x, y] = tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(4))

    draw_scr = ImageDraw.Draw(today_raw_1)
    draw_scr.text((380, 166), "31%", font=font(16, index=1), fill=(255, 138, 0, 255))
    draw_scr.text(
        (44, 234),
        "5 з 16 виконано",
        font=font(15, index=1),
        fill=(158, 158, 158, 255),
    )
    draw_scr.rounded_rectangle((45, 207, 168, 216), radius=4, fill=(255, 138, 0, 255))

    cx, cy, r = 53.5, 645.0, 14.0
    draw_scr.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 138, 0, 255))
    check_pts = [
        (cx - 5.5, cy - 0.5),
        (cx - 1.5, cy + 4.5),
        (cx + 6.0, cy - 4.5),
    ]
    draw_scr.line(check_pts[:2], fill=(255, 255, 255, 255), width=3)
    draw_scr.line(check_pts[1:], fill=(255, 255, 255, 255), width=3)

    cache["today_1"] = make_slide(
        today_raw_1, "Fix your day", "Habits and tasks, together"
    )

    # 3A. Habits Overview
    habits_raw = Image.open(
        SRC / "IMG_7122-71ce5da1-f578-40d8-a2bd-f9acba3b8536.png"
    ).convert("RGBA")
    cache["habits"] = make_slide(
        habits_raw, "Track every habit", "and see your progress"
    )

    # 3B. Habit Detail
    detail_raw = Image.open(
        SRC / "IMG_7121-ef6d71bf-4326-414b-b0ac-c3165329f15a.png"
    ).convert("RGBA")
    cache["habit_detail"] = make_slide(
        detail_raw, "See the days you showed up", "week by week"
    )

    # 4. AI Habit Recommendations
    ai_habits_raw = Image.open(
        SRC / "IMG_7126-5f934d9a-066b-40ca-8a18-8a4a5132db8e.png"
    ).convert("RGBA")
    cache["ai_habits"] = make_slide(
        ai_habits_raw, "Generate habits with AI", "for the goal you choose"
    )

    # 5. Home Widgets (from pre-rendered screenshot)
    cache["home_widgets"] = Image.open(
        OUT_DIR / "iphone-6.9/07-home-widgets.png"
    ).resize((W, H), Image.Resampling.LANCZOS).convert("RGBA")

    # 6. AI Helper Chat
    ai_helper_raw = Image.open(
        SRC / "IMG_7123-c3e5a49c-99bd-4a53-b239-8ae150a0e567.png"
    ).convert("RGBA")
    cache["ai_helper"] = make_slide(
        ai_helper_raw, "Get instant guidance", "from your AI Helper"
    )

    # 7. Outro Call to Action
    outro = create_base_gradient().convert("RGBA")
    outro.paste(glow, ((W - 500) // 2, 600), glow)
    outro.paste(logo, ((W - 320) // 2, 670), logo)
    draw_outro = ImageDraw.Draw(outro)
    draw_outro.text(
        ((W - draw_outro.textlength(t1, font=f_title)) // 2, 1050),
        t1,
        font=f_title,
        fill=WHITE,
    )
    draw_outro.text(
        ((W - draw_outro.textlength(t2, font=f_tag)) // 2, 1135),
        t2,
        font=f_tag,
        fill=ORANGE,
    )

    # App Store Badge / Call to Action
    badge_w, badge_h = 480, 96
    bx = (W - badge_w) // 2
    by = 1260
    draw_outro.rounded_rectangle(
        (bx, by, bx + badge_w, by + badge_h),
        radius=28,
        fill=(255, 138, 0, 255),
    )
    cta_font = font(36, index=1)
    cta_text = "Download on App Store"
    draw_outro.text(
        ((W - draw_outro.textlength(cta_text, font=cta_font)) // 2, by + 26),
        cta_text,
        font=cta_font,
        fill=(24, 24, 26, 255),
    )
    cache["outro"] = outro

    return cache


def render_frame(
    frame_idx: int, base_cache: dict[str, Image.Image]
) -> Image.Image:
    """Render a single frame of the preview video."""
    t = frame_idx / FPS  # time in seconds

    # Checkbox coordinates on base canvas for celebration particles
    cb_x = 186.0
    cb_y = 1227.0

    # Scene 1: Intro (0.0s - 2.2s, frames 0-66)
    if t < 2.2:
        im = base_cache["intro"].copy()
        # Fade in from black at the very start
        if t < 0.4:
            fade_in = t / 0.4
            im = Image.blend(
                Image.new("RGBA", (W, H), (18, 22, 28, 255)), im, fade_in
            )
        # Fade to Scene 2
        elif t > 1.8:
            fade_out = (2.2 - t) / 0.4
            im = Image.blend(base_cache["today_0"], im, fade_out)
        return im.convert("RGB")

    # Scene 2: Today (2.2s - 7.5s, frames 66-225)
    elif t < 7.5:
        # Before completion tap (2.2s - 4.5s)
        if t < 4.5:
            im = base_cache["today_0"].copy()
            # Tap cursor animation approaching checkbox at 4.2s - 4.5s
            if t > 4.1:
                cur_t = (t - 4.1) / 0.4
                cur_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                # Expanding subtle touch ring
                ring_r = 18.0 + 12.0 * cur_t
                ring_alpha = int(200 * (1.0 - cur_t * 0.4))
                ImageDraw.Draw(cur_layer).ellipse(
                    (cb_x - ring_r, cb_y - ring_r, cb_x + ring_r, cb_y + ring_r),
                    outline=(255, 138, 0, ring_alpha),
                    width=3,
                )
                im.paste(cur_layer, (0, 0), cur_layer)
        # After completion tap (4.5s - 7.5s)
        else:
            im = base_cache["today_1"].copy()
            burst_dt = t - 4.5  # time since tap
            if burst_dt < 1.2:
                burst_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                draw_b = ImageDraw.Draw(burst_layer)
                progress = min(1.0, burst_dt / 0.9)
                max_r = 75.0
                for i in range(12):
                    stagger = i * 0.028
                    local = max(0.0, min(1.0, (progress - stagger) / 0.88))
                    if local <= 0:
                        continue
                    ease = 1.0 - (1.0 - local) ** 3
                    dist = (
                        max_r * (0.55 + (0.45 if i % 2 == 0 else 0.22)) * ease
                    )
                    fade = max(0.0, min(1.0, 1.0 - local**2))
                    angle = (i / 12.0) * math.pi * 2 + 0.22
                    px_pos = cb_x + math.cos(angle) * dist
                    py_pos = cb_y + math.sin(angle) * dist

                    col = [ORANGE, (255, 220, 120), GOLD][i % 3]
                    alpha = int(255 * fade)
                    pr = (4.5 + (i % 3)) * (1.0 - local * 0.25)
                    draw_b.ellipse(
                        (px_pos - pr, py_pos - pr, px_pos + pr, py_pos + pr),
                        fill=col + (alpha,),
                    )

                # Expanding ring
                ring_ease = (
                    1.0 - (1.0 - (progress / 0.5)) ** 3
                    if progress < 0.5
                    else 1.0
                )
                ring_r = max_r * (0.28 + 0.82 * min(1.0, ring_ease))
                ring_alpha = int(255 * max(0.0, (1.0 - progress) * 0.4))
                if ring_alpha > 5:
                    draw_b.ellipse(
                        (
                            cb_x - ring_r,
                            cb_y - ring_r,
                            cb_x + ring_r,
                            cb_y + ring_r,
                        ),
                        outline=(255, 200, 100, ring_alpha),
                        width=2,
                    )

                im.paste(burst_layer, (0, 0), burst_layer)

        # Crossfade to Scene 3
        if t > 7.1:
            fade_out = (7.5 - t) / 0.4
            im = Image.blend(base_cache["habits"], im, fade_out)

        return im.convert("RGB")

    # Scene 3: Habits & Habit Detail (7.5s - 11.5s, frames 225-345)
    elif t < 11.5:
        # 3A. Habits list (7.5s - 9.5s)
        if t < 9.5:
            im = base_cache["habits"].copy()
            if t > 9.1:
                fade_sub = (9.5 - t) / 0.4
                im = Image.blend(base_cache["habit_detail"], im, fade_sub)
        # 3B. Habit Detail (9.5s - 11.5s)
        else:
            im = base_cache["habit_detail"].copy()
            if t > 11.1:
                fade_out = (11.5 - t) / 0.4
                im = Image.blend(base_cache["ai_habits"], im, fade_out)

        return im.convert("RGB")

    # Scene 4: AI Recommendations (11.5s - 15.5s, frames 345-465)
    elif t < 15.5:
        im = base_cache["ai_habits"].copy()
        if t > 15.1:
            fade_out = (15.5 - t) / 0.4
            im = Image.blend(base_cache["home_widgets"], im, fade_out)
        return im.convert("RGB")

    # Scene 5: Home Widgets (15.5s - 18.8s, frames 465-564)
    elif t < 18.8:
        im = base_cache["home_widgets"].copy()
        if t > 18.4:
            fade_out = (18.8 - t) / 0.4
            im = Image.blend(base_cache["ai_helper"], im, fade_out)
        return im.convert("RGB")

    # Scene 6: AI Helper & Outro (18.8s - 22.0s, frames 564-660)
    else:
        if t < 20.6:
            im = base_cache["ai_helper"].copy()
            if t > 20.2:
                fade_sub = (20.6 - t) / 0.4
                im = Image.blend(base_cache["outro"], im, fade_sub)
        else:
            im = base_cache["outro"].copy()
            # Gentle fade out to dark at the very end
            if t > 21.6:
                fade_end = (22.0 - t) / 0.4
                im = Image.blend(
                    Image.new("RGBA", (W, H), (18, 22, 28, 255)), im, fade_end
                )

        return im.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    temp_wav = Path("/tmp/principles_preview_audio.wav")
    out_mp4 = OUT_DIR / "app-preview-886x1920.mp4"
    out_mov = OUT_DIR / "app-preview-886x1920.mov"
    poster_png = OUT_DIR / "app-preview-poster-5s.png"

    print("=== 1. Synthesizing Soundtrack ===")
    generate_audio_track(temp_wav)

    print("=== 2. Pre-rendering Scene Visuals ===")
    base_cache = prepare_scene_base_images()

    print("=== 3. Saving Poster Frame at 00:00:05.000 ===")
    poster_frame_idx = int(5.0 * FPS)  # Frame 150
    poster_img = render_frame(poster_frame_idx, base_cache)
    poster_img.save(poster_png, "PNG")
    print(f"Saved poster frame to {poster_png} ({poster_img.size})")

    print(
        f"=== 4. Encoding Preview Video: {TOTAL_FRAMES} frames ({DURATION_SEC}s @ 30fps) ==="
    )
    cmd = [
        "ffmpeg",
        "-y",
        "-f",
        "rawvideo",
        "-vcodec",
        "rawvideo",
        "-s",
        f"{W}x{H}",
        "-pix_fmt",
        "rgb24",
        "-r",
        str(FPS),
        "-i",
        "-",
        "-i",
        str(temp_wav),
        "-c:v",
        "libx264",
        "-preset",
        "medium",
        "-b:v",
        "11M",
        "-maxrate",
        "12M",
        "-bufsize",
        "12M",
        "-profile:v",
        "high",
        "-level",
        "4.0",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "256k",
        "-ar",
        "44100",
        "-ac",
        "2",
        "-shortest",
        str(out_mp4),
    ]

    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)

    for i in range(TOTAL_FRAMES):
        frame = render_frame(i, base_cache)
        proc.stdin.write(frame.tobytes())
        if i % 60 == 0 or i == TOTAL_FRAMES - 1:
            print(
                f"  Rendered frame {i+1}/{TOTAL_FRAMES} ({ (i+1)/TOTAL_FRAMES*100:.1f}% )"
            )

    proc.stdin.close()
    proc.wait()

    if proc.returncode != 0:
        err = proc.stderr.read().decode("utf-8")
        print(f"FFmpeg error:\n{err}")
        sys.exit(proc.returncode)

    print(f"Successfully created: {out_mp4}")

    # Also create .mov container copy as allowed by Apple specs
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(out_mp4),
            "-c",
            "copy",
            str(out_mov),
        ],
        check=True,
        capture_output=True,
    )
    print(f"Successfully created: {out_mov}")

    print("\n=== 5. Verifying Compliance with ffprobe ===")
    probe = subprocess.run(
        ["ffprobe", "-hide_banner", str(out_mp4)],
        capture_output=True,
        text=True,
    )
    print(probe.stderr)


if __name__ == "__main__":
    main()
