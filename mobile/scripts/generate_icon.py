#!/usr/bin/env python3
"""
Build TrekTrack launcher / splash assets from the brand logo
(docs/static/assets/app-icon.png — car + speedometer + wordmark).
"""
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip3 install Pillow")
    raise

ROOT = Path(__file__).resolve().parents[2]  # mileage-tracker/
MOBILE = Path(__file__).resolve().parents[1]

BRAND_CANDIDATES = [
    ROOT / "docs" / "assets" / "app-icon.png",
    ROOT / "static" / "assets" / "app-icon.png",
]
OUT_DIR = MOBILE / "assets" / "icon"
OUT_ICON = OUT_DIR / "app_icon.png"
OUT_MARK = OUT_DIR / "app_mark.png"  # no wordmark, for small in-app marks
OUT_FG = OUT_DIR / "app_icon_foreground.png"  # adaptive icon safe zone


def load_brand() -> Image.Image:
    for p in BRAND_CANDIDATES:
        if p.exists():
            print(f"Source: {p}")
            return Image.open(p).convert("RGBA")
    raise SystemExit("Brand logo not found under docs/ or static/assets/app-icon.png")


def fit_square(src: Image.Image, size: int, bg: tuple[int, int, int, int], pad: float = 0.08) -> Image.Image:
    """Center src on a square canvas with solid background and edge padding."""
    canvas = Image.new("RGBA", (size, size), bg)
    max_side = int(size * (1.0 - 2 * pad))
    ratio = min(max_side / src.width, max_side / src.height)
    w = max(1, int(src.width * ratio))
    h = max(1, int(src.height * ratio))
    scaled = src.resize((w, h), Image.Resampling.LANCZOS)
    x = (size - w) // 2
    y = (size - h) // 2
    canvas.paste(scaled, (x, y), scaled)
    return canvas


def crop_mark(src: Image.Image) -> Image.Image:
    """
    Crop to the car + gauge region (drop wordmark) for small UI marks.
    Brand layout: graphic upper ~62%, wordmark sits in the lower band.
    """
    w, h = src.size
    top = int(h * 0.02)
    bottom = int(h * 0.62)
    left = int(w * 0.08)
    right = int(w * 0.92)
    return src.crop((left, top, right, bottom))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    brand = load_brand()

    # Light brand bg matches marketing site; solid for iOS (no alpha).
    light_bg = (241, 245, 249, 255)  # slate-100
    navy_bg = (10, 14, 20, 255)  # app dark bg

    # Full logo launcher icon (light, matches website).
    icon = fit_square(brand, 1024, light_bg, pad=0.06)
    # Flatten to RGB for iOS remove_alpha safety.
    icon_rgb = Image.new("RGB", icon.size, light_bg[:3])
    icon_rgb.paste(icon, mask=icon.split()[3])
    icon_rgb.save(OUT_ICON, "PNG")
    print(f"Wrote {OUT_ICON}")

    # Compact mark for in-app header (no wordmark).
    mark_src = crop_mark(brand)
    mark = fit_square(mark_src, 512, light_bg, pad=0.1)
    mark_rgb = Image.new("RGB", mark.size, light_bg[:3])
    mark_rgb.paste(mark, mask=mark.split()[3])
    mark_rgb.save(OUT_MARK, "PNG")
    print(f"Wrote {OUT_MARK}")

    # Adaptive foreground: mark on transparent with safe padding (~66% content).
    fg = fit_square(mark_src, 1024, (0, 0, 0, 0), pad=0.18)
    # Place on navy when alpha is fully transparent for tools that need RGB.
    fg_navy = Image.new("RGBA", (1024, 1024), navy_bg)
    fg_navy.paste(fg, mask=fg.split()[3] if fg.mode == "RGBA" else None)
    # Prefer transparent FG for adaptive; save RGBA with transparent pad.
    fg.save(OUT_FG, "PNG")
    print(f"Wrote {OUT_FG}")

    # Sync marketing favicons from mark (small).
    for dest_root in (ROOT / "docs" / "assets", ROOT / "static" / "assets"):
        if not dest_root.exists():
            continue
        for size, name in ((32, "favicon-32.png"), (192, "favicon-192.png")):
            small = mark_rgb.resize((size, size), Image.Resampling.LANCZOS)
            out = dest_root / name
            small.save(out, "PNG")
            print(f"Wrote {out}")
        # Keep full brand as site app-icon (already there); refresh from source.
        brand_rgb = Image.new("RGB", brand.size, light_bg[:3])
        brand_rgb.paste(brand, mask=brand.split()[3])
        brand_out = dest_root / "app-icon.png"
        brand_rgb.save(brand_out, "PNG")
        print(f"Wrote {brand_out}")


if __name__ == "__main__":
    main()
