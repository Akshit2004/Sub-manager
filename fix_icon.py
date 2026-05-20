"""
Fix the launcher icon properly:
1. Flood-fill remove ONLY the outer white background (not the white infinity symbol inside)
2. Crop to content and pad to a perfect 1024x1024 square
"""
from PIL import Image, ImageDraw

def flood_fill_transparent(img, start_x, start_y, threshold=235):
    """Flood fill from a starting point, making white-ish pixels transparent."""
    pixels = img.load()
    w, h = img.size
    visited = set()
    stack = [(start_x, start_y)]
    
    while stack:
        x, y = stack.pop()
        if (x, y) in visited:
            continue
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        
        r, g, b, a = pixels[x, y]
        # Only flood into white/near-white pixels
        if r > threshold and g > threshold and b > threshold:
            visited.add((x, y))
            pixels[x, y] = (0, 0, 0, 0)  # Make transparent
            # Check 4-connected neighbors
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        else:
            visited.add((x, y))

import sys
sys.setrecursionlimit(10000000)

# Load image
img = Image.open("assets/images/final_logo.png").convert("RGBA")
w, h = img.size
print(f"Original size: {w}x{h}")

# Increase stack size for flood fill by using iterative approach (already iterative above)
# Flood fill from all four corners and edges to remove only the OUTER white background
corners = [
    (0, 0), (w-1, 0), (0, h-1), (w-1, h-1),  # corners
    (w//2, 0), (w//2, h-1), (0, h//2), (w-1, h//2),  # edge midpoints
]

# Also add points along all four edges for thorough coverage
edge_points = []
step = 20
for x in range(0, w, step):
    edge_points.append((x, 0))
    edge_points.append((x, h - 1))
for y in range(0, h, step):
    edge_points.append((0, y))
    edge_points.append((w - 1, y))

all_start_points = corners + edge_points

for sx, sy in all_start_points:
    r, g, b, a = img.getpixel((sx, sy))
    if r > 235 and g > 235 and b > 235:
        flood_fill_transparent(img, sx, sy, threshold=235)

# Crop to the non-transparent bounding box
bbox = img.getbbox()
if bbox:
    cropped = img.crop(bbox)
else:
    cropped = img

cw, ch = cropped.size
print(f"Cropped size: {cw}x{ch}")

# Make it square with padding
max_dim = max(cw, ch)
padding = int(max_dim * 0.06)
canvas_size = max_dim + 2 * padding

square = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
x_offset = (canvas_size - cw) // 2
y_offset = (canvas_size - ch) // 2
square.paste(cropped, (x_offset, y_offset), cropped)

# Resize to 1024x1024
final = square.resize((1024, 1024), Image.LANCZOS)
final.save("assets/images/final_logo_fixed.png")
print(f"Final size: {final.size}")
print("Saved: assets/images/final_logo_fixed.png")
