"""Recreate the Xyles-neutral ground tint from the original CC0 Poly Haven map.
Requires Pillow. Run from any directory with Python.
"""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parent
source = Image.open(folder / "forest_ground_04-Diffuse.jpg").convert("L")
channels = [source.point(lambda value, scale=scale: min(255, int(value * scale)))
            for scale in (0.85, 0.91, 0.72)]
Image.merge("RGB", channels).save(folder / "forest_ground_tinted.png", optimize=True)
