from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
MASTER_SIZE = 1024
OUTPUT_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def scaled(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [
        (round(x * MASTER_SIZE / 108), round(y * MASTER_SIZE / 108))
        for x, y in points
    ]


def build_master() -> Image.Image:
    image = Image.new("RGB", (MASTER_SIZE, MASTER_SIZE), "#10131A")
    pixels = image.load()
    for y in range(MASTER_SIZE):
        progress = y / (MASTER_SIZE - 1)
        red = round(16 + 10 * progress)
        green = round(19 + 8 * progress)
        blue = round(26 + 20 * progress)
        for x in range(MASTER_SIZE):
            pixels[x, y] = (red, green, blue)

    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, MASTER_SIZE - 1, MASTER_SIZE - 1),
        radius=round(MASTER_SIZE * 24 / 108),
        fill=255,
    )
    transparent = Image.new("RGBA", image.size, (0, 0, 0, 0))
    transparent.paste(image.convert("RGBA"), mask=mask)
    draw = ImageDraw.Draw(transparent)
    draw.polygon(
        scaled(
            [
                (27, 23),
                (73, 23),
                (64, 34),
                (42, 34),
                (42, 47),
                (55, 47),
                (55, 59),
                (42, 59),
                (42, 85),
                (27, 85),
            ]
        ),
        fill="#42D9E8",
    )
    draw.polygon(
        scaled([(61, 48), (85, 65), (61, 82)]),
        fill="#9B7BFF",
    )
    return transparent


def main() -> None:
    master = build_master()
    branding = ROOT / "assets" / "branding"
    branding.mkdir(parents=True, exist_ok=True)
    master.save(branding / "flule34_icon_master.png", optimize=True)

    resources = ROOT / "android" / "app" / "src" / "main" / "res"
    for directory, size in OUTPUT_SIZES.items():
        output = resources / directory / "ic_launcher.png"
        output.parent.mkdir(parents=True, exist_ok=True)
        master.resize((size, size), Image.Resampling.LANCZOS).save(
            output,
            optimize=True,
        )


if __name__ == "__main__":
    main()
