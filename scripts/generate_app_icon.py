#!/usr/bin/env python3
"""Generate the placeholder 1024x1024 App Store icon (Soft Minimal palette, no alpha)."""
import sys
from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4  # supersample for smooth edges
BACKGROUND = (0xF7, 0xF6, 0xF2)
GRID = (0xDC, 0xE9, 0xE2)
ACCENT = (0x5E, 0x78, 0x67)
REST = (0xA8, 0xC4, 0xAF)

s = SIZE * SCALE
img = Image.new("RGB", (s, s), BACKGROUND)
draw = ImageDraw.Draw(img)

# 3x3 calendar grid of rounded cells; one cell left open as "余白".
margin, gap = int(s * 0.18), int(s * 0.045)
cell = (s - 2 * margin - 2 * gap) // 3
radius = int(cell * 0.22)
for row in range(3):
    for col in range(3):
        x0 = margin + col * (cell + gap)
        y0 = margin + row * (cell + gap)
        box = (x0, y0, x0 + cell, y0 + cell)
        if (row, col) == (1, 1):
            draw.rounded_rectangle(box, radius, outline=ACCENT, width=int(s * 0.014))
        elif (row, col) == (2, 2):
            draw.rounded_rectangle(box, radius, fill=REST)
        else:
            draw.rounded_rectangle(box, radius, fill=GRID)

img = img.resize((SIZE, SIZE), Image.LANCZOS)
img.save(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png", optimize=True)
