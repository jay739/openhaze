"""Generates AppIcon.ico: the same dim-window-behind / bright-amber-window-in-
front mark already drawn at runtime for the tray icon (see TrayIconRenderer in
OpenHaze.cs), refined for use as the .exe/installer icon at larger sizes.
Usage: python3 makeicon.py [/path/to/AppIcon.ico]
"""

import sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.ico"
S = 4  # supersample factor for smooth downscaling
SIZE = 256 * S

DIM = (96, 96, 104, 255)
BRIGHT = (255, 196, 92, 255)
OUTLINE = (0, 0, 0, 90)
PLATE_TOP = (40, 46, 66, 255)
PLATE_BOTTOM = (13, 15, 26, 255)


def rounded_rect(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def make_plate(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        t = y / size
        r = int(PLATE_TOP[0] + (PLATE_BOTTOM[0] - PLATE_TOP[0]) * t)
        g = int(PLATE_TOP[1] + (PLATE_BOTTOM[1] - PLATE_TOP[1]) * t)
        b = int(PLATE_TOP[2] + (PLATE_BOTTOM[2] - PLATE_TOP[2]) * t)
        ImageDraw.Draw(img).line([(0, y), (size, y)], fill=(r, g, b, 255))
    mask = Image.new("L", (size, size), 0)
    margin = int(size * 0.08)
    rounded_rect(
        ImageDraw.Draw(mask),
        (margin, margin, size - margin, size - margin),
        radius=int(size * 0.22),
        fill=255,
    )
    plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    plate.paste(img, (0, 0), mask)
    return plate


def draw_icon():
    base = make_plate(SIZE)

    # soft shadow for the front window, drawn first so it sits underneath
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    fw = (int(SIZE * 0.34), int(SIZE * 0.40), int(SIZE * 0.86), int(SIZE * 0.86))
    rounded_rect(sd, fw, radius=int(SIZE * 0.07), fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=SIZE * 0.03))
    base.alpha_composite(shadow, (int(SIZE * 0.01), int(SIZE * 0.02)))

    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # dim back window (upper-left)
    back = (int(SIZE * 0.14), int(SIZE * 0.12), int(SIZE * 0.66), int(SIZE * 0.58))
    rounded_rect(
        d, back, radius=int(SIZE * 0.06), fill=DIM, outline=OUTLINE, width=max(1, S)
    )

    # bright front window (lower-right, overlapping)
    front = (int(SIZE * 0.34), int(SIZE * 0.40), int(SIZE * 0.86), int(SIZE * 0.86))
    rounded_rect(
        d, front, radius=int(SIZE * 0.07), fill=BRIGHT, outline=OUTLINE, width=max(1, S)
    )

    base.alpha_composite(layer)
    return base


def main():
    master = draw_icon()
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [master.resize((s, s), Image.LANCZOS) for s in sizes]
    frames[-1].save(
        OUT,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=frames[:-1],
    )
    print("Wrote", OUT)
    png_out = OUT.rsplit(".", 1)[0] + "-512.png"
    master.resize((512, 512), Image.LANCZOS).save(png_out)
    print("Wrote", png_out)


if __name__ == "__main__":
    main()
