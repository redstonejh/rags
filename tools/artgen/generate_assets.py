#!/usr/bin/env python3
"""Generate deterministic programmer-art assets for RAGS."""

from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
TILE = 32
TILES_DIR = ROOT / "assets" / "tiles"
CHARS_DIR = ROOT / "assets" / "chars"
PROPS_DIR = ROOT / "assets" / "props"
UI_DIR = ROOT / "assets" / "ui"
BUILDINGS_DIR = ROOT / "assets" / "buildings"
TERRAIN_PATH = TILES_DIR / "terrain_atlas.png"
BODY_PATH = CHARS_DIR / "body_base.png"
PLAYER_OUTFIT_PATH = CHARS_DIR / "outfit_player.png"
NPC_OUTFIT_PATH = CHARS_DIR / "outfit_npc.png"
DOOR_PATH = PROPS_DIR / "door.png"
SHOP_COUNTER_PATH = PROPS_DIR / "shop_counter.png"
PARKED_CAR_PATH = PROPS_DIR / "parked_car.png"
BUILDING_ASSET_PATHS = {
    "roof_tile": BUILDINGS_DIR / "roof_tile.png",
    "facade_plain": BUILDINGS_DIR / "facade_plain.png",
    "facade_window_lit": BUILDINGS_DIR / "facade_window_lit.png",
    "facade_window_dark": BUILDINGS_DIR / "facade_window_dark.png",
    "awning_red": BUILDINGS_DIR / "awning_red.png",
    "awning_green": BUILDINGS_DIR / "awning_green.png",
}
BUILDING_SIGNS = {
    "loc_diner": "MEL'S",
    "loc_store": "QUIKSTOP",
    "loc_offices": "VANTAGE",
    "loc_bar": "ANCHOR",
    "loc_bricks": "BRICKS",
    "loc_site": "SITE 9",
    "loc_rowhouse_a": "ROW EAST",
    "loc_rowhouse_b": "ROW WEST",
}
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


def _draw_brick_pattern(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
                        mortar: tuple[int, int, int, int]) -> None:
    for y in range(y0, y1 + 1, 8):
        draw.line((x0, y, x1, y), fill=mortar)
        offset = 0 if ((y - y0) // 8) % 2 == 0 else 10
        for x in range(x0 + offset, x1 + 1, 20):
            draw.line((x, y, x, min(y1, y + 7)), fill=mortar)


def draw_roof_tile() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(0, 12), (15, 2), (31, 12), (31, 31), (0, 31)],
                 fill=(83, 62, 56, 255))
    draw.polygon([(2, 13), (15, 5), (29, 13), (29, 20), (2, 20)],
                 fill=(121, 82, 63, 255))
    for y in range(14, 31, 6):
        draw.line((2, y, 29, y), fill=(64, 46, 44, 255))
    for x in range(4, 31, 8):
        draw.line((x, 13, x - 2, 30), fill=(96, 61, 52, 255))
    draw.line((15, 3, 30, 12), fill=(164, 113, 81, 255))
    BUILDING_ASSET_PATHS["roof_tile"].parent.mkdir(parents=True, exist_ok=True)
    img.save(BUILDING_ASSET_PATHS["roof_tile"])
    print(f"wrote {BUILDING_ASSET_PATHS['roof_tile'].relative_to(ROOT)}")


def _facade_base() -> Image:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, 31, 47), fill=(105, 94, 89, 255))
    draw.rectangle((0, 0, 31, 4), fill=(138, 126, 116, 255))
    draw.rectangle((0, 42, 31, 47), fill=(67, 61, 62, 255))
    _draw_brick_pattern(draw, 1, 5, 30, 42, (76, 70, 72, 255))
    return img


def draw_facade(path: Path, window: str = "") -> None:
    img = _facade_base()
    draw = ImageDraw.Draw(img)
    if window:
        glow = (220, 186, 91, 255) if window == "lit" else (45, 55, 67, 255)
        shadow = (88, 65, 46, 255) if window == "lit" else (30, 35, 43, 255)
        draw.rectangle((8, 13, 24, 29), fill=shadow)
        draw.rectangle((10, 15, 22, 27), fill=glow)
        draw.line((16, 15, 16, 27), fill=shadow)
        draw.line((10, 21, 22, 21), fill=shadow)
        draw.rectangle((7, 29, 25, 31), fill=(55, 49, 49, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def draw_awning(path: Path, color: tuple[int, int, int]) -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    dark = tuple(max(0, c - 48) for c in color)
    draw.rectangle((2, 12, 29, 19), fill=(*dark, 255))
    for x in range(2, 30, 6):
        draw.rectangle((x, 12, min(x + 4, 29), 23), fill=(*color, 255))
    draw.line((2, 23, 29, 23), fill=(45, 40, 38, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def draw_sign(path: Path, text: str) -> None:
    img = Image.new("RGBA", (96, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((3, 5, 92, 20), fill=(43, 39, 43, 255))
    draw.rectangle((5, 7, 90, 18), fill=(178, 68, 53, 255))
    draw.rectangle((7, 8, 88, 17), outline=(238, 230, 196, 255))
    font = ImageFont.load_default()
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text(((96 - tw) // 2, (24 - th) // 2 - 1), text, font=font,
              fill=(246, 237, 190, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def generate_buildings() -> None:
    draw_roof_tile()
    draw_facade(BUILDING_ASSET_PATHS["facade_plain"])
    draw_facade(BUILDING_ASSET_PATHS["facade_window_lit"], "lit")
    draw_facade(BUILDING_ASSET_PATHS["facade_window_dark"], "dark")
    draw_awning(BUILDING_ASSET_PATHS["awning_red"], (178, 68, 53))
    draw_awning(BUILDING_ASSET_PATHS["awning_green"], (65, 119, 88))
    for loc_id, label in BUILDING_SIGNS.items():
        draw_sign(BUILDINGS_DIR / ("sign_%s.png" % loc_id), label)


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
    generate_buildings()
    generate_characters()
    generate_props()
    generate_ui()


if __name__ == "__main__":
    main()
