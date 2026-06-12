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
BODY_WALK_PATH = CHARS_DIR / "body_base_walk.png"
PLAYER_OUTFIT_WALK_PATH = CHARS_DIR / "outfit_player_walk.png"
NPC_OUTFIT_WALK_PATH = CHARS_DIR / "outfit_npc_walk.png"
PLAYER_CLOTHING_WALK_PATHS = {
    "hoodie": CHARS_DIR / "outfit_hoodie_walk.png",
    "thrift_blazer": CHARS_DIR / "outfit_thrift_blazer_walk.png",
    "nice_suit": CHARS_DIR / "outfit_nice_suit_walk.png",
    "ski_mask": CHARS_DIR / "outfit_ski_mask_walk.png",
}
DOOR_PATH = PROPS_DIR / "door.png"
SHOP_COUNTER_PATH = PROPS_DIR / "shop_counter.png"
PARKED_CAR_PATH = PROPS_DIR / "parked_car.png"
FRIDGE_PATH = PROPS_DIR / "fridge.png"
BED_PATH = PROPS_DIR / "bed.png"
SHOWER_PATH = PROPS_DIR / "shower.png"
TV_PATH = PROPS_DIR / "tv.png"
BENCH_PATH = PROPS_DIR / "bench.png"
STREET_LAMP_PATH = PROPS_DIR / "street_lamp.png"
TRASH_CAN_PATH = PROPS_DIR / "trash_can.png"
DUMPSTER_PATH = PROPS_DIR / "dumpster.png"
NEWS_BOX_PATH = PROPS_DIR / "news_box.png"
BAR_COUNTER_PATH = PROPS_DIR / "bar_counter.png"
RECORDS_DESK_PATH = PROPS_DIR / "records_desk.png"
WORK_SPOT_PATH = PROPS_DIR / "work_spot.png"
DEALER_SPOT_PATH = PROPS_DIR / "dealer_spot.png"
FENCE_SPOT_PATH = PROPS_DIR / "fence_spot.png"
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


def draw_body_frame(draw: ImageDraw.ImageDraw, ox: int, oy: int, direction: int, frame: int) -> None:
    skin = (194, 143, 102, 255)
    skin_shadow = (139, 93, 68, 255)
    hair = (54, 38, 31, 255)
    foot_shift = [-1, 0, 1, 0][frame]
    bob = 1 if frame in [1, 3] else 0
    # Legs and hands.
    draw.rectangle((ox + 11 - foot_shift, oy + 31, ox + 14 - foot_shift, oy + 42), fill=skin_shadow)
    draw.rectangle((ox + 18 + foot_shift, oy + 31, ox + 21 + foot_shift, oy + 42), fill=skin_shadow)
    draw.rectangle((ox + 7 + foot_shift, oy + 24, ox + 10 + foot_shift, oy + 30), fill=skin)
    draw.rectangle((ox + 22 - foot_shift, oy + 24, ox + 25 - foot_shift, oy + 30), fill=skin)
    # Neck and head.
    draw.rectangle((ox + 14, oy + 14 + bob, ox + 18, oy + 20 + bob), fill=skin_shadow)
    draw.rectangle((ox + 10, oy + 4 + bob, ox + 22, oy + 16 + bob), fill=skin)
    if direction == 2:  # up/back
        draw.rectangle((ox + 9, oy + 4 + bob, ox + 23, oy + 16 + bob), fill=hair)
        draw.rectangle((ox + 11, oy + 15 + bob, ox + 21, oy + 18 + bob), fill=hair)
    elif direction == 1:  # right
        draw.rectangle((ox + 10, oy + 3 + bob, ox + 22, oy + 8 + bob), fill=hair)
        draw.rectangle((ox + 9, oy + 7 + bob, ox + 13, oy + 14 + bob), fill=hair)
        draw.point((ox + 20, oy + 10 + bob), fill=(30, 24, 22, 255))
        draw.line((ox + 17, oy + 14 + bob, ox + 21, oy + 14 + bob), fill=(116, 65, 61, 255))
    elif direction == 3:  # left
        draw.rectangle((ox + 10, oy + 3 + bob, ox + 22, oy + 8 + bob), fill=hair)
        draw.rectangle((ox + 19, oy + 7 + bob, ox + 23, oy + 14 + bob), fill=hair)
        draw.point((ox + 12, oy + 10 + bob), fill=(30, 24, 22, 255))
        draw.line((ox + 11, oy + 14 + bob, ox + 15, oy + 14 + bob), fill=(116, 65, 61, 255))
    else:
        draw.rectangle((ox + 11, oy + 3 + bob, ox + 21, oy + 7 + bob), fill=hair)
        draw.rectangle((ox + 9, oy + 7 + bob, ox + 12, oy + 13 + bob), fill=hair)
        draw.rectangle((ox + 20, oy + 7 + bob, ox + 23, oy + 13 + bob), fill=hair)
        draw.point((ox + 13, oy + 10 + bob), fill=(30, 24, 22, 255))
        draw.point((ox + 19, oy + 10 + bob), fill=(30, 24, 22, 255))
        draw.line((ox + 14, oy + 14 + bob, ox + 18, oy + 14 + bob), fill=(116, 65, 61, 255))


def draw_body_base() -> None:
    CHARS_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_body_frame(draw, 0, 0, 0, 1)
    img.save(BODY_PATH)
    print(f"wrote {BODY_PATH.relative_to(ROOT)}")


def draw_outfit_frame(draw: ImageDraw.ImageDraw, ox: int, oy: int, direction: int, frame: int,
                      color: tuple[int, int, int], trim: tuple[int, int, int],
                      mask: bool = False) -> None:
    main = (*color, 255)
    dark = (*tuple(max(0, c - 38) for c in color), 255)
    trim_rgba = (*trim, 255)
    foot_shift = [-1, 0, 1, 0][frame]
    bob = 1 if frame in [1, 3] else 0
    # Shirt/jacket.
    draw.rectangle((ox + 9, oy + 18 + bob, ox + 23, oy + 31 + bob), fill=main)
    draw.rectangle((ox + 8 + foot_shift, oy + 20 + bob, ox + 11 + foot_shift, oy + 27 + bob), fill=dark)
    draw.rectangle((ox + 21 - foot_shift, oy + 20 + bob, ox + 24 - foot_shift, oy + 27 + bob), fill=dark)
    if direction == 2:
        draw.rectangle((ox + 11, oy + 19 + bob, ox + 21, oy + 21 + bob), fill=dark)
    elif direction == 1:
        draw.line((ox + 20, oy + 18 + bob, ox + 20, oy + 31 + bob), fill=trim_rgba)
        draw.rectangle((ox + 15, oy + 19 + bob, ox + 22, oy + 21 + bob), fill=trim_rgba)
    elif direction == 3:
        draw.line((ox + 12, oy + 18 + bob, ox + 12, oy + 31 + bob), fill=trim_rgba)
        draw.rectangle((ox + 10, oy + 19 + bob, ox + 17, oy + 21 + bob), fill=trim_rgba)
    else:
        draw.line((ox + 16, oy + 18 + bob, ox + 16, oy + 31 + bob), fill=trim_rgba)
        draw.rectangle((ox + 12, oy + 19 + bob, ox + 20, oy + 21 + bob), fill=trim_rgba)
    # Pants and shoes.
    draw.rectangle((ox + 10 - foot_shift, oy + 31, ox + 15 - foot_shift, oy + 42), fill=(45, 47, 54, 255))
    draw.rectangle((ox + 17 + foot_shift, oy + 31, ox + 22 + foot_shift, oy + 42), fill=(45, 47, 54, 255))
    draw.rectangle((ox + 9 - foot_shift, oy + 42, ox + 15 - foot_shift, oy + 44), fill=(28, 25, 24, 255))
    draw.rectangle((ox + 17 + foot_shift, oy + 42, ox + 23 + foot_shift, oy + 44), fill=(28, 25, 24, 255))
    if mask:
        mask_color = (28, 30, 32, 255)
        eye = (216, 202, 164, 255)
        draw.rectangle((ox + 10, oy + 4 + bob, ox + 22, oy + 16 + bob), fill=mask_color)
        if direction == 2:
            draw.rectangle((ox + 11, oy + 15 + bob, ox + 21, oy + 18 + bob), fill=mask_color)
        elif direction == 1:
            draw.rectangle((ox + 17, oy + 9 + bob, ox + 21, oy + 11 + bob), fill=eye)
        elif direction == 3:
            draw.rectangle((ox + 11, oy + 9 + bob, ox + 15, oy + 11 + bob), fill=eye)
        else:
            draw.rectangle((ox + 12, oy + 9 + bob, ox + 20, oy + 11 + bob), fill=eye)


def draw_outfit(path: Path, color: tuple[int, int, int], trim: tuple[int, int, int]) -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_outfit_frame(draw, 0, 0, 0, 1, color, trim)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def draw_body_walk_sheet() -> None:
    img = Image.new("RGBA", (32 * 4, 48 * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for direction in range(4):
        for frame in range(4):
            draw_body_frame(draw, frame * 32, direction * 48, direction, frame)
    img.save(BODY_WALK_PATH)
    print(f"wrote {BODY_WALK_PATH.relative_to(ROOT)}")


def draw_outfit_walk_sheet(path: Path, color: tuple[int, int, int], trim: tuple[int, int, int],
                           mask: bool = False) -> None:
    img = Image.new("RGBA", (32 * 4, 48 * 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for direction in range(4):
        for frame in range(4):
            draw_outfit_frame(draw, frame * 32, direction * 48, direction, frame, color, trim, mask)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT)}")


def generate_characters() -> None:
    draw_body_base()
    draw_outfit(PLAYER_OUTFIT_PATH, (64, 98, 178), (211, 218, 235))
    draw_outfit(NPC_OUTFIT_PATH, (210, 210, 210), (250, 250, 250))
    draw_body_walk_sheet()
    draw_outfit_walk_sheet(PLAYER_OUTFIT_WALK_PATH, (64, 98, 178), (211, 218, 235))
    draw_outfit_walk_sheet(NPC_OUTFIT_WALK_PATH, (210, 210, 210), (250, 250, 250))
    draw_outfit_walk_sheet(PLAYER_CLOTHING_WALK_PATHS["hoodie"], (92, 98, 105), (180, 186, 190))
    draw_outfit_walk_sheet(PLAYER_CLOTHING_WALK_PATHS["thrift_blazer"], (96, 80, 62), (212, 197, 163))
    draw_outfit_walk_sheet(PLAYER_CLOTHING_WALK_PATHS["nice_suit"], (34, 42, 58), (232, 232, 222))
    draw_outfit_walk_sheet(PLAYER_CLOTHING_WALK_PATHS["ski_mask"], (48, 50, 52), (120, 126, 130), True)


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


def draw_fridge() -> None:
    img = Image.new("RGBA", (32, 44), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((7, 3, 25, 40), fill=(210, 218, 220, 255))
    draw.rectangle((9, 5, 23, 38), fill=(235, 240, 239, 255))
    draw.line((9, 17, 23, 17), fill=(116, 127, 132, 255))
    draw.rectangle((11, 8, 13, 15), fill=(89, 102, 108, 255))
    draw.rectangle((11, 23, 13, 34), fill=(89, 102, 108, 255))
    draw.rectangle((8, 39, 24, 41), fill=(112, 118, 120, 255))
    FRIDGE_PATH.parent.mkdir(parents=True, exist_ok=True)
    img.save(FRIDGE_PATH)
    print(f"wrote {FRIDGE_PATH.relative_to(ROOT)}")


def draw_bed() -> None:
    img = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((5, 10, 43, 27), fill=(87, 58, 42, 255))
    draw.rectangle((8, 7, 40, 23), fill=(86, 105, 155, 255))
    draw.rectangle((10, 8, 22, 16), fill=(215, 220, 223, 255))
    draw.rectangle((24, 8, 38, 16), fill=(190, 198, 214, 255))
    draw.rectangle((8, 19, 40, 24), fill=(54, 69, 112, 255))
    img.save(BED_PATH)
    print(f"wrote {BED_PATH.relative_to(ROOT)}")


def draw_shower() -> None:
    img = Image.new("RGBA", (32, 44), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((7, 11, 25, 39), fill=(105, 144, 155, 255))
    draw.rectangle((9, 13, 23, 37), fill=(153, 194, 205, 255))
    draw.arc((9, 2, 25, 20), 180, 270, fill=(185, 190, 184, 255), width=2)
    draw.rectangle((21, 8, 27, 11), fill=(185, 190, 184, 255))
    for x in [14, 17, 20, 23]:
        draw.line((x, 13, x - 2, 20), fill=(105, 144, 155, 180))
    img.save(SHOWER_PATH)
    print(f"wrote {SHOWER_PATH.relative_to(ROOT)}")


def draw_tv() -> None:
    img = Image.new("RGBA", (40, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((6, 7, 34, 25), fill=(34, 35, 39, 255))
    draw.rectangle((9, 10, 27, 21), fill=(52, 67, 80, 255))
    draw.rectangle((29, 11, 32, 14), fill=(184, 64, 55, 255))
    draw.rectangle((29, 17, 32, 20), fill=(92, 142, 151, 255))
    draw.line((15, 25, 11, 30), fill=(34, 35, 39, 255), width=2)
    draw.line((25, 25, 29, 30), fill=(34, 35, 39, 255), width=2)
    img.save(TV_PATH)
    print(f"wrote {TV_PATH.relative_to(ROOT)}")


def draw_bench() -> None:
    img = Image.new("RGBA", (48, 28), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for y in [8, 14, 20]:
        draw.rectangle((5, y, 43, y + 3), fill=(112, 69, 42, 255))
        draw.line((5, y + 3, 43, y + 3), fill=(65, 43, 34, 255))
    for x in [10, 36]:
        draw.rectangle((x, 6, x + 3, 25), fill=(48, 48, 52, 255))
    img.save(BENCH_PATH)
    print(f"wrote {BENCH_PATH.relative_to(ROOT)}")


def draw_street_lamp() -> None:
    img = Image.new("RGBA", (32, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((15, 19, 17, 57), fill=(52, 53, 56, 255))
    draw.rectangle((11, 55, 21, 60), fill=(38, 38, 42, 255))
    draw.rectangle((10, 11, 22, 20), fill=(58, 49, 42, 255))
    draw.rectangle((12, 13, 20, 18), fill=(230, 199, 106, 255))
    draw.rectangle((13, 9, 19, 12), fill=(43, 43, 47, 255))
    img.save(STREET_LAMP_PATH)
    print(f"wrote {STREET_LAMP_PATH.relative_to(ROOT)}")


def draw_trash_can() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((10, 9, 22, 27), fill=(75, 89, 82, 255))
    draw.rectangle((9, 7, 23, 10), fill=(111, 126, 115, 255))
    draw.rectangle((11, 27, 21, 29), fill=(47, 58, 54, 255))
    for x in [13, 17, 21]:
        draw.line((x, 11, x - 1, 26), fill=(49, 62, 58, 255))
    img.save(TRASH_CAN_PATH)
    print(f"wrote {TRASH_CAN_PATH.relative_to(ROOT)}")


def draw_dumpster() -> None:
    img = Image.new("RGBA", (64, 36), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((6, 10, 58, 29), fill=(49, 93, 72, 255))
    draw.rectangle((8, 7, 56, 13), fill=(65, 119, 88, 255))
    draw.rectangle((12, 15, 25, 26), fill=(35, 73, 57, 255))
    draw.rectangle((39, 15, 52, 26), fill=(35, 73, 57, 255))
    draw.rectangle((10, 29, 18, 32), fill=(31, 32, 34, 255))
    draw.rectangle((46, 29, 54, 32), fill=(31, 32, 34, 255))
    img.save(DUMPSTER_PATH)
    print(f"wrote {DUMPSTER_PATH.relative_to(ROOT)}")


def draw_news_box() -> None:
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((8, 8, 24, 27), fill=(158, 49, 44, 255))
    draw.rectangle((10, 10, 22, 16), fill=(238, 230, 196, 255))
    draw.rectangle((10, 18, 22, 24), fill=(95, 33, 34, 255))
    draw.rectangle((13, 27, 19, 30), fill=(78, 36, 35, 255))
    img.save(NEWS_BOX_PATH)
    print(f"wrote {NEWS_BOX_PATH.relative_to(ROOT)}")


def draw_bar_counter() -> None:
    img = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((4, 12, 44, 26), fill=(75, 45, 32, 255))
    draw.rectangle((4, 9, 44, 14), fill=(121, 72, 43, 255))
    for x in [10, 20, 30, 39]:
        draw.rectangle((x, 5, x + 3, 10), fill=(218, 185, 82, 255))
    draw.rectangle((8, 17, 40, 23), fill=(55, 32, 28, 255))
    img.save(BAR_COUNTER_PATH)
    print(f"wrote {BAR_COUNTER_PATH.relative_to(ROOT)}")


def draw_records_desk() -> None:
    img = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((5, 12, 43, 26), fill=(99, 94, 75, 255))
    draw.rectangle((5, 9, 43, 14), fill=(146, 138, 104, 255))
    draw.rectangle((10, 15, 21, 23), fill=(67, 63, 56, 255))
    draw.rectangle((27, 6, 38, 10), fill=(230, 225, 199, 255))
    draw.line((28, 8, 37, 8), fill=(84, 78, 68, 255))
    img.save(RECORDS_DESK_PATH)
    print(f"wrote {RECORDS_DESK_PATH.relative_to(ROOT)}")


def draw_work_spot() -> None:
    img = Image.new("RGBA", (44, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((5, 13, 39, 26), fill=(77, 66, 55, 255))
    draw.rectangle((5, 10, 39, 15), fill=(118, 96, 72, 255))
    draw.rectangle((12, 5, 27, 11), fill=(52, 62, 70, 255))
    draw.rectangle((14, 6, 25, 9), fill=(95, 129, 138, 255))
    draw.rectangle((29, 8, 35, 11), fill=(215, 210, 178, 255))
    img.save(WORK_SPOT_PATH)
    print(f"wrote {WORK_SPOT_PATH.relative_to(ROOT)}")


def draw_dealer_spot() -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((11, 16, 21, 34), fill=(50, 59, 48, 255))
    draw.rectangle((10, 7, 22, 17), fill=(132, 94, 72, 255))
    draw.rectangle((9, 6, 23, 10), fill=(32, 35, 31, 255))
    draw.rectangle((8, 20, 11, 30), fill=(42, 48, 40, 255))
    draw.rectangle((21, 20, 24, 30), fill=(42, 48, 40, 255))
    draw.rectangle((11, 34, 15, 43), fill=(38, 40, 40, 255))
    draw.rectangle((17, 34, 21, 43), fill=(38, 40, 40, 255))
    img.save(DEALER_SPOT_PATH)
    print(f"wrote {DEALER_SPOT_PATH.relative_to(ROOT)}")


def draw_fence_spot() -> None:
    img = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((9, 18, 23, 35), fill=(61, 46, 69, 255))
    draw.rectangle((10, 7, 22, 18), fill=(161, 114, 82, 255))
    draw.rectangle((8, 4, 24, 9), fill=(44, 35, 47, 255))
    draw.rectangle((7, 22, 10, 30), fill=(50, 38, 57, 255))
    draw.rectangle((22, 22, 25, 30), fill=(50, 38, 57, 255))
    draw.rectangle((11, 35, 15, 43), fill=(35, 31, 36, 255))
    draw.rectangle((17, 35, 21, 43), fill=(35, 31, 36, 255))
    draw.rectangle((20, 14, 24, 16), fill=(218, 185, 82, 255))
    img.save(FENCE_SPOT_PATH)
    print(f"wrote {FENCE_SPOT_PATH.relative_to(ROOT)}")


def generate_props() -> None:
    draw_door()
    draw_shop_counter()
    draw_parked_car()
    draw_fridge()
    draw_bed()
    draw_shower()
    draw_tv()
    draw_bench()
    draw_street_lamp()
    draw_trash_can()
    draw_dumpster()
    draw_news_box()
    draw_bar_counter()
    draw_records_desk()
    draw_work_spot()
    draw_dealer_spot()
    draw_fence_spot()


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
