"""
Собирает все иконки из assets/icons/*.png в один атлас assets/icons-sheet.png
(5 колонок, клетка 200×200) и генерирует src/shared/IconMap.luau с координатами.

Запуск (после node tools/render_icons.js):
    python3 tools/build_spritesheet.py
"""

import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICONS = sorted((ROOT / "assets" / "icons").glob("*.png"))
CELL = 200
COLUMNS = 5

rows = (len(ICONS) + COLUMNS - 1) // COLUMNS
sheet = Image.new("RGBA", (CELL * COLUMNS, CELL * rows), (0, 0, 0, 0))
entries = []
for index, path in enumerate(ICONS):
    icon = Image.open(path).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
    x, y = (index % COLUMNS) * CELL, (index // COLUMNS) * CELL
    sheet.alpha_composite(icon, (x, y))
    entries.append((path.stem, x, y))

sheet.save(ROOT / "assets" / "icons-sheet.png")

lines = [
    "--[[",
    "\tIconMap — СГЕНЕРИРОВАНО tools/build_spritesheet.py, руками не править.",
    "\tКоординаты иконок в атласе assets/icons-sheet.png.",
    "]]",
    "",
    "return {",
    f"\tcellSize = {CELL},",
    "\ticons = {",
]
for name, x, y in entries:
    lines.append(f"\t\t{name} = Vector2.new({x}, {y}),")
lines += ["\t},", "}", ""]
(ROOT / "src" / "shared" / "IconMap.luau").write_text("\n".join(lines), encoding="utf-8")
print(f"{len(entries)} icons -> icons-sheet.png {sheet.size}")
