#!/usr/bin/env python3
"""Generate deterministic programmer-art assets for RAGS.

The current game still builds most visuals in code. This starts the Phase 0
asset pipeline with a committed terrain atlas matching TileWorld's existing
five tile coordinates:

0 grass, 1 road, 2 floor, 3 wall, 4 solid floor under walls.
"""

from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TILE = 32
OUT_DIR = ROOT / "assets" / "tiles"
OUT_PATH = OUT_DIR / "terrain_atlas.png"
SEED = 741_2026


PALETTES = {
    "grass": {
        "base": (60, 104, 54),
        "dark": (42, 78, 43),
        "light": (83, 132, 67),
        "accent": (125, 142, 74),
    },
    "road": {
        "base": (70, 70, 74),
        "dark": (48, 48, 54),
        "light": (90, 90, 94),
        "accent": (116, 112, 94),
    },
    "floor": {
        "base": (121, 91, 60),
        "dark": (85, 61, 43),
        "light": (151, 113, 73),
        "accent": (101, 71, 48),
    },
    "wall": {
        "base": (92, 88, 96),
        "dark": (63, 61, 70),
        "light": (121, 116, 126),
        "accent": (74, 72, 80),
    },
}


def jitter(color: tuple[int, int, int], amount: int, rng: random.Random) -> tuple[int, int, int]:
    return tuple(max(0, min(255, c + rng.randint(-amount, amount))) for c in color)


def draw_grass(draw: ImageDraw.ImageDraw, x0: int, rng: random.Random) -> None:
    p = PALETTES["grass"]
    draw.rectangle((x0, 0, x0 + TILE - 1, TILE - 1), fill=p["base"])
    for _ in range(90):
        x = x0 + rng.randrange(TILE)
        y = rng.randrange(TILE)
        color = jitter(p["light"] if rng.random() < 0.45 else p["dark"], 10, rng)
        draw.point((x, y), fill=color)
        if rng.random() < 0.25 and y + 1 < TILE:
            draw.point((x, y + 1), fill=color)
    for _ in range(4):
        x = x0 + rng.randrange(2, TILE - 3)
        y = rng.randrange(2, TILE - 3)
        draw.line((x, y, x + rng.choice([-1, 1]), y - 2), fill=p["accent"])


def draw_road(draw: ImageDraw.ImageDraw, x0: int, rng: random.Random) -> None:
    p = PALETTES["road"]
    draw.rectangle((x0, 0, x0 + TILE - 1, TILE - 1), fill=p["base"])
    for y in range(0, TILE, 4):
        draw.line((x0, y, x0 + TILE - 1, y), fill=p["dark"])
    for _ in range(70):
        x = x0 + rng.randrange(TILE)
        y = rng.randrange(TILE)
        draw.point((x, y), fill=jitter(p["light"] if rng.random() < 0.4 else p["dark"], 8, rng))
    draw.rectangle((x0, 0, x0 + TILE - 1, 1), fill=p["dark"])
    draw.rectangle((x0, TILE - 2, x0 + TILE - 1, TILE - 1), fill=p["dark"])


def draw_floor(draw: ImageDraw.ImageDraw, x0: int, rng: random.Random, solid: bool = False) -> None:
    p = PALETTES["floor"]
    draw.rectangle((x0, 0, x0 + TILE - 1, TILE - 1), fill=p["base"])
    for y in range(0, TILE, 8):
        draw.rectangle((x0, y, x0 + TILE - 1, y + 1), fill=p["dark"])
    for x in range(0, TILE, 16):
        draw.line((x0 + x, 0, x0 + x, TILE - 1), fill=p["accent"])
    for _ in range(40):
        x = x0 + rng.randrange(TILE)
        y = rng.randrange(TILE)
        draw.point((x, y), fill=jitter(p["light"], 12, rng))
    if solid:
        for i in range(0, TILE, 4):
            draw.point((x0 + i, i), fill=p["dark"])
            draw.point((x0 + TILE - 1 - i, i), fill=p["dark"])


def draw_wall(draw: ImageDraw.ImageDraw, x0: int, rng: random.Random) -> None:
    p = PALETTES["wall"]
    draw.rectangle((x0, 0, x0 + TILE - 1, TILE - 1), fill=p["base"])
    for y in range(0, TILE, 8):
        draw.rectangle((x0, y, x0 + TILE - 1, y + 1), fill=p["dark"])
    for row, offset in enumerate((0, 10, 4, 14)):
        y = row * 8
        for x in range(offset, TILE, 16):
            draw.line((x0 + x, y, x0 + x, min(TILE - 1, y + 7)), fill=p["dark"])
    draw.rectangle((x0, 0, x0 + TILE - 1, 2), fill=p["light"])
    draw.rectangle((x0, TILE - 3, x0 + TILE - 1, TILE - 1), fill=p["dark"])
    for _ in range(30):
        x = x0 + rng.randrange(TILE)
        y = rng.randrange(TILE)
        draw.point((x, y), fill=jitter(p["accent"], 8, rng))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = random.Random(SEED)
    img = Image.new("RGB", (TILE * 5, TILE))
    draw = ImageDraw.Draw(img)
    draw_grass(draw, 0 * TILE, rng)
    draw_road(draw, 1 * TILE, rng)
    draw_floor(draw, 2 * TILE, rng)
    draw_wall(draw, 3 * TILE, rng)
    draw_floor(draw, 4 * TILE, rng, solid=True)
    img.save(OUT_PATH)
    print(f"wrote {OUT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
