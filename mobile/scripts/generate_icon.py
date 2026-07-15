#!/usr/bin/env python3
"""Generate a simple 1024x1024 app icon for Mileage Tracker."""
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("Install Pillow: pip3 install Pillow")
    raise

OUT = Path(__file__).resolve().parent.parent / "assets" / "icon" / "app_icon.png"
OUT.parent.mkdir(parents=True, exist_ok=True)

size = 1024
img = Image.new("RGBA", (size, size), (10, 14, 20, 255))
draw = ImageDraw.Draw(img)

# Rounded square background
margin = 80
draw.rounded_rectangle(
    [margin, margin, size - margin, size - margin],
    radius=180,
    fill=(59, 158, 255, 255),
)

# Route line (stylized "mile" path)
points = [
    (280, 620), (380, 480), (520, 520), (620, 360), (740, 400),
]
draw.line(points, fill=(255, 255, 255, 255), width=48, joint="curve")

# Dots at ends
for x, y in [points[0], points[-1]]:
    draw.ellipse([x - 36, y - 36, x + 36, y + 36], fill=(52, 211, 153, 255))

img.save(OUT)
print(f"Wrote {OUT}")