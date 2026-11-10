#!/usr/bin/env python3
"""Generate every visual asset for the Sisyphus DMS plugin.

All artwork is original pixel art written programmatically (Pillow + stdlib).
Deterministic output: fixed seeds, no external assets. MIT licensed.

The scene is ENDLESS (Camus): the slope exits the canvas top-right, there is
no summit, no flag, no finish line. The illusion of endless progress comes
from a conveyor of surface chips and a slowly scrolling parallax ridge.
"""
import math
import os
import random
import struct
import wave

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")

# ---------------------------------------------------------------- palette
INK = (26, 28, 44, 255)
SKY = (0, 0, 0, 0)                      # transparent in every sprite
ROCK_BASE = (104, 106, 132, 255)
ROCK_DARK = (72, 74, 100, 255)
ROCK_DEEP = (58, 60, 84, 255)
ROCK_LIGHT = (140, 142, 168, 255)
ROCK_SNOW = (220, 222, 232, 255)
BOULDER_BASE = (152, 142, 150, 255)
BOULDER_DARK = (104, 96, 108, 255)
BOULDER_LIGHT = (190, 182, 192, 255)
SKIN = (212, 158, 110, 255)
SKIN_DARK = (176, 126, 86, 255)
TUNIC = (232, 232, 240, 255)
TUNIC_DARK = (176, 178, 194, 255)
HAIR = (52, 42, 40, 255)
GRASS = (96, 128, 92, 255)
GRASS_DARK = (72, 100, 70, 255)
RIDGE = (88, 92, 120, 255)
RIDGE_DARK = (70, 74, 102, 255)

# ---------------------------------------------------------------- scene geometry
CANVAS_W, CANVAS_H = 160, 120
SX0, SY0 = 22, 104                      # slope enters canvas at lower-left
# Slope direction is fixed by dirX/dirY; the line runs off the top-right
# corner (no endpoint on canvas). Direction: 130/147.65 right, -70/147.65 up.
DENX, DENY = 130.0, -70.0
SLOPE_LEN = math.hypot(DENX, DENY)
DIR = (DENX / SLOPE_LEN, DENY / SLOPE_LEN)
NORM = (DIR[1], -DIR[0])                # surface normal pointing up-left


def slope_y_top(x: int) -> float:
    """Top silhouette of the slope for texture column x (0..159)."""
    if x < 22:
        return float("inf")
    t = x - SX0
    y = SY0 + t * (DENY / DENX)
    if y < -1.0:
        return float("inf")             # slope already left the canvas
    return y


def draw_mountain_body() -> Image.Image:
    """Static endless slope: gradient fill, ink edges, faint strata. No summit."""
    img = Image.new("RGBA", (CANVAS_W, CANVAS_H), SKY)
    px = img.load()

    # --- body fill below the slope edge ---
    for x in range(CANVAS_W):
        top = slope_y_top(x)
        if top > CANVAS_H - 1:
            continue
        for y in range(int(math.ceil(top)), CANVAS_H):
            depth = y - top
            shade = ROCK_LIGHT if depth < 2 else ROCK_BASE
            if depth > 42:
                shade = ROCK_DARK
            if depth > 70:
                shade = ROCK_DEEP
            px[x, y] = shade

    # foot wedge: slope base runs off the bottom-left canvas edge
    for x in range(22):
        ytop = 104 + (22 - x) * (16 / 22)
        for y in range(int(math.ceil(ytop)), CANVAS_H):
            depth = y - ytop
            shade = ROCK_LIGHT if depth < 2 else ROCK_BASE
            if depth > 20:
                shade = ROCK_DARK
            if y > 112:
                shade = ROCK_DEEP
            px[x, y] = shade

    # faint strata lines parallel to the slope (static texture, low contrast)
    draw = ImageDraw.Draw(img)
    for k in (14, 34, 58):
        x0, y0 = SX0 + DIR[0] * k, SY0 + DIR[1] * k
        x1, y1 = SX0 + DIR[0] * (k + 300), SY0 + DIR[1] * (k + 300) * 0.5
        # dashed dark band parallel to the slope at normal depth k*0.42
        depth = k * 0.42
        bx = -NORM[0] * depth
        by = -NORM[1] * depth
        steps = 130
        for i in range(steps):
            t = i / steps * 190
            xx = SX0 + DIR[0] * t + bx
            yy = SY0 + DIR[1] * t + by
            if 0 <= int(xx) < CANVAS_W and 0 <= int(yy) < CANVAS_H:
                if i % 7 < 4:
                    px[int(xx), int(yy)] = ROCK_DARK

    # ink edge along the slope
    for x in range(22, CANVAS_W):
        top = slope_y_top(x)
        if top < CANVAS_H:
            yy = int(round(top))
            if 0 <= yy < CANVAS_H:
                px[x, yy] = INK
    # base edge (22,104) -> (0,120)
    for i in range(16):
        x = round(22 - i * (22 / 16))
        y = 104 + i
        if 0 <= x < CANVAS_W:
            px[x, y] = INK

    # static high-altitude snow patches near the top edge (slow parallax claim
    # comes from chips; these are far-in-depth scenery, faint)
    rnd = random.Random(7)
    for x in range(60, CANVAS_W):
        top = slope_y_top(x)
        if top > -1 and 30 < x and rnd.random() < 0.06:
            depth = rnd.randint(10, 24)
            yy = top + depth
            if 0 <= yy < CANVAS_H and px[x, int(yy)] not in (INK,):
                px[x, int(yy)] = ROCK_SNOW
    return img


def draw_far_ridge() -> Image.Image:
    """Far parallax ridge: tileable horizontally."""
    w, h = 160, 44
    img = Image.new("RGBA", (w, h), SKY)
    px = img.load()
    rnd = random.Random(13)
    # peaks as a periodic skyline: heights repeat with wrap
    heights = [0] * w
    for i in range(9):
        cx = int(i * w / 9 + 4)
        ph = 12 + rnd.randint(0, 8)
        for d in range(16):
            xx = (cx + d) % w
            yy = ph - d * (ph - 6) / 16
            heights[xx] = max(heights[xx], yy)
    for x in range(w):
        top = int(heights[x])
        for y in range(top, h):
            px[x, y] = RIDGE if y < top + 2 else RIDGE_DARK
        if heights[(x - 1 + w) % w] > heights[x]:
            px[x, top] = INK                     # ridge outline
    # snow on a few peaks
    for _ in range(14):
        x = rnd.randrange(w)
        y = heights[x] + 1
        px[x, y] = ROCK_SNOW
    return img


def draw_chip(kind: str) -> Image.Image:
    """Small surface details for the scrolling conveyor."""
    sizes = {"pebble": (7, 5), "snow": (6, 4), "tuft": (5, 7)}
    w, h = sizes[kind]
    img = Image.new("RGBA", (w, h), SKY)
    px = img.load()
    if kind == "pebble":
        for x in range(1, 6):
            px[x, 2 + (x in (2, 4))] = ROCK_DARK
        px[1, 3] = px[5, 3] = ROCK_DARK
        px[2, 2] = px[3, 2] = ROCK_LIGHT
    elif kind == "snow":
        for x in range(1, 5):
            px[x, 1] = ROCK_SNOW
        px[2, 2] = px[3, 2] = ROCK_SNOW
        px[2, 0] = ROCK_SNOW
    else:  # tuft
        for x in range(1, 4):
            px[x, 5] = GRASS_DARK
        px[2, 2] = dx = GRASS
        px[1, 3] = px[3, 3] = GRASS
        px[2, 1] = GRASS
        px[1, 4] = px[2, 4] = px[3, 4] = GRASS_DARK
    return img


def draw_cloud() -> Image.Image:
    w, h = 34, 12
    img = Image.new("RGBA", (w, h), SKY)
    px = img.load()
    rnd = random.Random(19)
    for _ in range(46):
        x, y = rnd.randint(2, w - 3), rnd.randint(2, h - 3)
        px[x, y] = (232, 236, 246, rnd.randint(70, 150))
    for x in range(8, 24):
        px[x, 7] = (232, 236, 246, 120)
    return img


def save(img: Image.Image, name: str) -> None:
    path = os.path.join(SPRITES, name)
    img.save(path, optimize=True)
    print("wrote", path, img.size)


# ---------------------------------------------------------------- character frames
def _new_char() -> tuple:
    img = Image.new("RGBA", (28, 28), SKY)
    return img, img.load()


def _head(px) -> None:
    # Smaller profile head keeps the human proportions distinct from a mascot.
    for y in range(3, 9):
        for x in range(8, 14):
            px[x, y] = INK
    for y in range(5, 9):
        for x in range(9, 14):
            px[x, y] = SKIN
    for x in range(8, 13):
        px[x, 4] = HAIR
    for y in range(5, 7):
        px[8, y] = HAIR
    px[9, 6] = HAIR
    px[12, 6] = INK
    px[14, 7] = SKIN_DARK


def _limb(draw: ImageDraw.ImageDraw, points: tuple, color: tuple, width: int = 3) -> None:
    draw.line(points, fill=INK, width=width + 2, joint="curve")
    draw.line(points, fill=color, width=width, joint="curve")


def _draw_tunic(draw: ImageDraw.ImageDraw, lean: int = 0) -> None:
    body = [(9 + lean, 9), (14 + lean, 10), (17 + lean, 15),
            (15 + lean, 19), (10 + lean, 17)]
    draw.polygon(body, fill=TUNIC, outline=INK)
    draw.line((10 + lean, 16, 15 + lean, 17), fill=TUNIC_DARK, width=2)
    draw.line((11 + lean, 11, 13 + lean, 13), fill=TUNIC_DARK, width=1)
    draw.line((10 + lean, 18, 15 + lean, 19), fill=HAIR, width=1)


def _draw_idle(img: Image.Image, px) -> Image.Image:
    draw = ImageDraw.Draw(img)
    _head(px)
    _draw_tunic(draw)
    _limb(draw, (11, 17, 10, 22, 8, 24), SKIN_DARK, 3)
    _limb(draw, (15, 17, 16, 22, 18, 24), SKIN_DARK, 3)
    draw.line((6, 25, 10, 25), fill=INK, width=3)
    draw.line((16, 25, 20, 25), fill=INK, width=3)
    _limb(draw, (10, 12, 7, 15, 8, 18), SKIN, 2)
    _limb(draw, (15, 13, 19, 15, 19, 18), SKIN, 2)
    return img


def frame_idle() -> Image.Image:
    img, px = _new_char()
    return _draw_idle(img, px)


def frame_push(variant: int) -> Image.Image:
    img, px = _new_char()
    draw = ImageDraw.Draw(img)
    _head(px)
    lean = 1 + variant
    _draw_tunic(draw, lean)
    # One bent knee drives toward the boulder; the back leg is stretched and planted.
    _limb(draw, (13 + lean, 17, 12, 21, 16, 23), SKIN_DARK, 3)
    _limb(draw, (10 + lean, 17, 7, 21, 3, 23), SKIN_DARK, 3)
    draw.line((14, 24, 18, 24), fill=INK, width=3)
    draw.line((1, 24, 5, 24), fill=INK, width=3)
    # Both arms extend forward at separate heights, with palms against the rock.
    high_y = 11 + variant
    low_y = 15 + variant
    _limb(draw, (15 + lean, 11, 19, high_y, 24, high_y), SKIN, 3)
    _limb(draw, (16 + lean, 14, 20, low_y, 24, low_y), SKIN_DARK, 3)
    draw.rectangle((24, high_y - 1, 27, high_y + 1), fill=INK)
    draw.rectangle((25, high_y - 1, 27, high_y), fill=SKIN)
    draw.rectangle((24, low_y - 1, 27, low_y + 1), fill=INK)
    draw.rectangle((25, low_y - 1, 27, low_y), fill=SKIN_DARK)
    return img


def draw_stone_roll() -> None:
    """Write a short, quiet, deterministic gravelly stone-roll sound."""
    sample_rate = 44100
    duration = 0.34
    samples = int(sample_rate * duration)
    rng = random.Random(73)
    low_noise = 0.0
    mid_noise = 0.0
    impacts = []

    impact_time = 0.018
    while impact_time < duration * 0.82:
        impacts.append((
            int(impact_time * sample_rate),
            rng.uniform(0.35, 0.8),
            rng.uniform(105.0, 205.0),
            rng.uniform(240.0, 520.0),
            rng.uniform(0.018, 0.045),
        ))
        impact_time += rng.uniform(0.035, 0.075)

    with wave.open(os.path.join(ROOT, "assets", "sounds", "stone_roll.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(sample_rate)
        values = []
        for i in range(samples):
            t = i / sample_rate
            white = rng.uniform(-1.0, 1.0)
            low_noise += 0.018 * (white - low_noise)
            mid_noise += 0.19 * (white - mid_noise)
            scrape = mid_noise - low_noise
            envelope = math.sin(math.pi * t / duration) ** 0.7
            rumble = low_noise * 0.18
            grit = scrape * 0.24 + white * 0.025
            value = envelope * (rumble + grit)

            for start, amplitude, low_tone, high_tone, decay in impacts:
                age = (i - start) / sample_rate
                if 0 <= age < decay * 4:
                    attack = 1.0 - math.exp(-age / 0.0012)
                    tail = math.exp(-age / decay)
                    body = math.sin(2 * math.pi * low_tone * age)
                    grit_tone = math.sin(2 * math.pi * high_tone * age + 0.35)
                    value += amplitude * attack * tail * (0.62 * body + 0.2 * grit_tone)

            values.append(value)

        peak = max(abs(value) for value in values) or 1.0
        scale = 0.72 / peak
        data = bytearray()
        for value in values:
            sample = int(max(-1.0, min(1.0, value * scale)) * 32767)
            data.extend(struct.pack("<h", sample))
        out.writeframes(data)


# ---------------------------------------------------------------- boulder
BOULDER_R = 11


def draw_boulder() -> Image.Image:
    size = BOULDER_R * 2 + 4             # padding so rotation never clips
    img = Image.new("RGBA", (size, size), SKY)
    px = img.load()
    c = (size - 1) / 2
    rnd = random.Random(11)
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if r > BOULDER_R:
                continue
            z = r / BOULDER_R
            shade = BOULDER_BASE
            theta = math.degrees(math.atan2(dy, dx)) % 360
            if 100 <= theta <= 245 and z > 0.3:
                shade = BOULDER_DARK          # bottom-left shadowed half
            if z > 0.86:
                shade = BOULDER_DARK
            if 295 <= theta <= 25 and z > 0.55 and z < 0.92:
                shade = BOULDER_LIGHT         # top-right rim catch-light
            if z <= 0.3:
                shade = BOULDER_BASE
            px[x, y] = shade
    # outline ring
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            if BOULDER_R - 0.8 < r <= BOULDER_R + 0.4:
                px[x, y] = INK
    # a few small pits in the lower half (never reads as a face)
    draw = ImageDraw.Draw(img)
    draw.line((c - 5, c + 1, c - 3, c + 2), fill=BOULDER_DARK)
    draw.line((c + 4, c + 2, c + 5, c + 0), fill=BOULDER_DARK)
    for a_deg, rr in ((12, 6.5), (68, 4.5), (118, 7), (208, 5), (302, 6.5), (245, 4)):
        a = math.radians(a_deg)
        x, y = int(c + rr * math.cos(a)), int(c + rr * math.sin(a))
        if 0 <= x < size and 0 <= y < size:
            px[x, y] = BOULDER_DARK
    return img


if __name__ == "__main__":
    os.makedirs(SPRITES, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "assets", "sounds"), exist_ok=True)
    save(draw_mountain_body(), "mountain_body.png")
    save(draw_far_ridge(), "far_ridge.png")
    save(draw_chip("pebble"), "chip_pebble.png")
    save(draw_chip("snow"), "chip_snow.png")
    save(draw_chip("tuft"), "chip_tuft.png")
    save(draw_cloud(), "cloud.png")
    save(frame_idle(), "sisyphus_idle.png")
    save(frame_push(0), "sisyphus_push1.png")
    save(frame_push(1), "sisyphus_push2.png")
    save(draw_boulder(), "boulder.png")
    draw_stone_roll()
