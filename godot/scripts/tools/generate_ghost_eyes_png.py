from pathlib import Path
from PIL import Image, ImageDraw

base = Path("c:/Users/Angel/Work/School Classes/GAME 399/Game/Waka-Lika/godot/assets/characters")
base.mkdir(parents=True, exist_ok=True)

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Eyes only (white), no pupils.
for ex in (90, 166):
    d.ellipse((ex - 24, 96 - 24, ex + 24, 96 + 24), fill=(255, 255, 255, 255))

img.save(base / "ghost-eyes.png")
print("wrote ghost-eyes.png")
