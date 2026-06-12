#!/usr/bin/env python3
"""Generate deterministic programmer-art assets for RAGS."""

from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TILE = 32
TILES_DIR = ROOT / "assets" / "tiles"
CHARS_DIR = ROOT / "assets" / "chars"
PROPS_DIR = ROOT / "assets" / "props"
UI_DIR = ROOT / "assets" / "ui"
TERRAIN_PATH = TILES_DIR / "terrain_atlas.png"
BODY_PATH = CHARS_DIR / "body_base.png"
PLAYER_OUTFIT_PATH = CHARS_DIR / "outfit_player.png"
NPC_OUTFIT_PATH = CHARS_DIR / "outfit_npc.png"
DOOR_PATH = PROPS_DIR / "door.png"
SHOP_COUNTER_PATH = PROPS_DIR / "shop_counter.png"
PARKED_CAR_PATH = PROPS_DIR / "parked_car.png"
UI_ICON_PATHS = {
    "resume": UI_DIR / "icon_resume.png",
    "save": UI_DIR / "icon_save.png",
    "walk": UI_DIR / "icon_walk.png",
    "quit": UI_DIR / "icon_quit.png",
}
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


def generate_terrain(rng: random.Random) -> None:
    TILES_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (TILE * 5, TILE))
    draw = ImageDraw.Draw(img)
    draw_grass(draw, 0 * TILE, rng)
    draw_road(draw, 1 * TILE, rng)
    draw_floor(draw, 2 * TILE, rng)
    draw_wall(draw, 3 * TILE, rng)
    draw_floor(draw, 4 * TILE, rng, solid=True)
    img.save(TERRAIN_PATH)
    print(f"wrote {TERRAIN_PATH.relative_to(ROOT)}")


def draw_body_base() -> None:
    CHARS_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    skin = (194, 143, 102, 255)
    skin_shadow = (139, 93, 68, 255)
    hair = (54, 38, 31, 255)
    # Legs and hands.
    draw.rectangle((11, 31, 14, 42), fill=skin_shadow)
    draw.rectangle((18, 31, 21, 42), fill=skin_shadow)
    draw.rectangle((7, 24, 10, 30), fill=skin)
    draw.rectangle((22, 24, 25, 30), fill=skin)
    # Neck and face.
    draw.rectangle((14, 14, 18, 20), fill=skin_shadow)
    draw.rectangle((10, 4, 22, 16), fill=skin)
    draw.rectangle((11, 3, 21, 7), fill=hair)
    draw.rectangle((9, 7, 12, 13), fill=hair)
    draw.rectangle((20, 7, 23, 13), fill=hair)
    draw.point((13, 10), fill=(30, 24, 22, 255))
    draw.point((19, 10), fill=(30, 24, 22, 255))
    draw.line((14, 14, 18, 14), fill=(116, 65, 61, 255))
    img.save(BODY_PATH)
    print(f"wrote {BODY_PATH.relative_to(ROOT)}")


def draw_outfit(path: Path, color: tuple[int, int, int], trim: tuple[int, int, int]) -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    main = (*color, 255)
    dark = (*tuple(max(0, c - 38) for c in color), 255)
    trim_rgba = (*trim, 255)
    # Shirt/jacket.
    draw.rectangle((9, 18, 23, 31), fill=main)
    draw.rectangle((8, 20, 11, 27), fill=dark)
    draw.rectangle((21, 20, 24, 27), fill=dark)
    draw.line((16, 18, 16, 31), fill=trim_rgba)
    draw.rectangle((12, 19, 20, 21), fill=trim_rgba)
    # Pants and shoes.
    draw.rectangle((10, 31, 15, 42), fill=(45, 47, 54, 255))
    draw.rectangle((17, 31, 22, 42), fill=(45, 47, 54, 255))
    draw.rectangle((9, 42, 15, 44), fill=(28, 25, 24, 255))
    draw.rectangle((17, 42, 23, 44), fill=(28, 25, 24, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def generate_characters() -> None:
    draw_body_base()
    draw_outfit(PLAYER_OUTFIT_PATH, (64, 98, 178), (211, 218, 235))
    draw_outfit(NPC_OUTFIT_PATH, (210, 210, 210), (250, 250, 250))


def draw_door() -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((7, 8, 25, 43), fill=(78, 48, 31, 255))
    draw.rectangle((9, 10, 23, 41), fill=(116, 72, 43, 255))
    draw.rectangle((11, 13, 21, 24), fill=(73, 42, 30, 255))
    draw.rectangle((11, 28, 21, 38), fill=(73, 42, 30, 255))
    draw.rectangle((22, 25, 24, 28), fill=(212, 181, 70, 255))
    draw.rectangle((6, 43, 26, 45), fill=(52, 34, 27, 255))
    DOOR_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(DOOR_PATH)
    print(f"wrote {DOOR_PATH.relative_to(ROOT)}")


def draw_shop_counter() -> None:
    img = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((4, 10, 44, 25), fill=(65, 105, 116, 255))
    draw.rectangle((4, 8, 44, 13), fill=(92, 142, 151, 255))
    draw.rectangle((8, 14, 19, 23), fill=(43, 76, 85, 255))
    draw.rectangle((27, 14, 39, 23), fill=(43, 76, 85, 255))
    draw.rectangle((31, 4, 42, 9), fill=(190, 192, 166, 255))
    draw.rectangle((33, 2, 40, 5), fill=(88, 91, 82, 255))
    SHOP_COUNTER_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(SHOP_COUNTER_PATH)
    print(f"wrote {SHOP_COUNTER_PATH.relative_to(ROOT)}")


def draw_parked_car() -> None:
    img = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((7, 12, 57, 29), fill=(214, 214, 218, 255))
    draw.rectangle((12, 8, 52, 18), fill=(232, 232, 235, 255))
    draw.rectangle((17, 10, 28, 17), fill=(45, 57, 68, 255))
    draw.rectangle((36, 10, 47, 17), fill=(45, 57, 68, 255))
    draw.rectangle((9, 25, 17, 33), fill=(30, 30, 32, 255))
    draw.rectangle((47, 25, 55, 33), fill=(30, 30, 32, 255))
    draw.rectangle((5, 16, 8, 23), fill=(222, 196, 87, 255))
    draw.rectangle((56, 16, 59, 23), fill=(180, 54, 48, 255))
    PARKED_CAR_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(PARKED_CAR_PATH)
    print(f"wrote {PARKED_CAR_PATH.relative_to(ROOT)}")


def generate_props() -> None:
    draw_door()
    draw_shop_counter()
    draw_parked_car()


def _icon_base() -> Image:
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def _save_icon(path: Path, draw_fn) -> None:
    UI_DIR.mkdir(parents=True, exist_ok=True)
    img = _icon_base()
    draw = ImageDraw.Draw(img)
    draw_fn(draw)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def generate_ui() -> None:
    ink = (238, 230, 196, 255)
    shadow = (58, 48, 42, 255)
    accent = (178, 68, 53, 255)

    def resume(draw: ImageDraw.ImageDraw) -> None:
        draw.polygon([(5, 3), (12, 8), (5, 13)], fill=shadow)
        draw.polygon([(6, 4), (11, 8), (6, 12)], fill=ink)

    def save(draw: ImageDraw.ImageDraw) -> None:
        draw.rectangle((3, 2, 13, 14), fill=shadow)
        draw.rectangle((4, 3, 12, 13), fill=ink)
        draw.rectangle((5, 4, 10, 7), fill=(76, 87, 98, 255))
        draw.rectangle((6, 10, 11, 13), fill=shadow)

    def walk(draw: ImageDraw.ImageDraw) -> None:
        draw.ellipse((5, 1, 10, 6), fill=ink)
        draw.line((8, 6, 7, 10), fill=ink, width=2)
        draw.line((7, 8, 3, 9), fill=ink, width=2)
        draw.line((7, 10, 4, 14), fill=ink, width=2)
        draw.line((7, 10, 12, 13), fill=ink, width=2)

    def quit_icon(draw: ImageDraw.ImageDraw) -> None:
        draw.rectangle((3, 3, 11, 13), outline=ink, width=2)
        draw.line((8, 8, 14, 8), fill=accent, width=2)
        draw.polygon([(12, 5), (15, 8), (12, 11)], fill=accent)

    _save_icon(UI_ICON_PATHS["resume"], resume)
    _save_icon(UI_ICON_PATHS["save"], save)
    _save_icon(UI_ICON_PATHS["walk"], walk)
    _save_icon(UI_ICON_PATHS["quit"], quit_icon)


def main() -> None:
    rng = random.Random(SEED)
    generate_terrain(rng)
    generate_characters()
    generate_props()
    generate_ui()


if __name__ == "__main__":
    main()
