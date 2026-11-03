"""
Генератор моделей питомцев → src/shared/PetSpecs.json.

Каждый питомец — набор простых деталей (эллипсоид, блок, клин, цилиндр).
Координаты в studs, центр — между лапками на земле, «вперёд» — это -Z.
Rojo превращает JSON в ModuleScript, поэтому игра строит питомцев из этих же данных,
а tools/preview_pets.js рендерит их в браузере для проверки.

Запуск:
    python3 tools/pets.py && node tools/preview_pets.js
"""

import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# --- матрицы поворота ---------------------------------------------------------


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def _rx(d):
    r = math.radians(d)
    c, s = math.cos(r), math.sin(r)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def _ry(d):
    r = math.radians(d)
    c, s = math.cos(r), math.sin(r)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def _rz(d):
    r = math.radians(d)
    c, s = math.cos(r), math.sin(r)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def rot(x=0, y=0, z=0):
    """Сначала поворот вокруг X, затем Y, затем Z (в градусах)."""
    return _mul(_rz(z), _mul(_ry(y), _rx(x)))


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


IDENTITY = rot()

# --- построитель --------------------------------------------------------------


class Pet:
    def __init__(self):
        self.parts = []

    def add(self, shape, size, pos, color, r=None, material="SmoothPlastic", transparency=0):
        part = {
            "s": shape,
            "z": [round(v, 3) for v in size],
            "p": [round(v, 3) for v in pos],
            "c": color,
        }
        if r is not None and r != IDENTITY:
            part["r"] = [round(v, 4) for row in r for v in row]
        if material != "SmoothPlastic":
            part["m"] = material
        if transparency:
            part["t"] = transparency
        self.parts.append(part)
        return self

    def ell(self, size, pos, color, r=None, **kw):
        return self.add("ell", size, pos, color, r, **kw)

    def block(self, size, pos, color, r=None, **kw):
        return self.add("block", size, pos, color, r, **kw)

    def mirror(self, fn):
        """fn(sign) вызывается для левой (-1) и правой (+1) стороны."""
        fn(-1)
        fn(1)
        return self

    def triangle(self, center, width, height, thick, color, tilt_z=0, tilt_x=0, **kw):
        """Равнобедренный треугольник (ухо, рог, шип) из двух клиньев, остриём вверх."""
        base = rot(x=tilt_x, z=tilt_z)
        for sign in (-1, 1):
            # Клин Roblox: срез смотрит в -Z, высокая грань сзади (+Z).
            # Поворот на ∓90° по Y ставит треугольник в плоскость XY, вертикальной гранью к центру.
            half = _mul(base, _ry(90 if sign < 0 else -90))
            offset = apply(base, [sign * width / 4, 0, 0])
            pos = [center[i] + offset[i] for i in range(3)]
            self.add("wedge", [thick, height, width / 2], pos, color, half, **kw)
        return self

    def eyes(self, head_c, head_r, dx=0.3, dy=0.1, size=0.3, color="#1B1A24", shine=True):
        for sign in (-1, 1):
            d = [sign * dx, dy, -1.0]
            n = math.sqrt(sum(v * v for v in d))
            p = [head_c[i] + d[i] / n * head_r[i] * 0.93 for i in range(3)]
            self.ell([size, size * 1.2, size * 0.55], p, color)
            if shine:
                self.ell(
                    [size * 0.34, size * 0.34, size * 0.2],
                    [p[0] + size * 0.16, p[1] + size * 0.24, p[2] - size * 0.24],
                    "#FFFFFF",
                    material="Neon",
                )
        return self

    def cheeks(self, head_c, head_r, dx=0.55, dy=-0.2, color="#FF9EB5"):
        for sign in (-1, 1):
            d = [sign * dx, dy, -0.85]
            n = math.sqrt(sum(v * v for v in d))
            p = [head_c[i] + d[i] / n * head_r[i] * 0.95 for i in range(3)]
            self.ell([0.26, 0.14, 0.08], p, color, transparency=0.15)
        return self

    def front(self, head_c, head_r, dy=0.0):
        """Точка на передней поверхности головы (для носа, клюва)."""
        d = [0, dy, -1.0]
        n = math.sqrt(sum(v * v for v in d))
        return [head_c[i] + d[i] / n * head_r[i] for i in range(3)]


def head_half(size):
    return [size[0] / 2, size[1] / 2, size[2] / 2]


# --- питомцы ------------------------------------------------------------------

PETS = {}


def pet(pet_id, glow=None, sparkles=False, fire=False):
    def wrap(fn):
        p = Pet()
        fn(p)
        PETS[pet_id] = {"parts": p.parts, "glow": glow, "sparkles": sparkles, "fire": fire}
        return fn

    return wrap


def classic_body(p, color, belly, head_size=(1.5, 1.35, 1.35), head_y=1.35):
    """Круглая голова + тело + лапки — основа для котёнка, щенка, зайчика, панды, лисы."""
    p.ell([1.15, 1.0, 1.2], [0, 0.5, 0.2], color)
    p.ell([0.75, 0.7, 0.4], [0, 0.5, -0.25], belly)
    p.mirror(lambda s: p.ell([0.36, 0.28, 0.42], [s * 0.3, 0.13, -0.28], color))
    hc = [0, head_y, -0.05]
    p.ell(list(head_size), hc, color)
    return hc, head_half(head_size)


@pet("Kitten")
def kitten(p):
    hc, hr = classic_body(p, "#F6A24C", "#FFE3C2")
    p.triangle([-0.42, 1.98, 0.0], 0.5, 0.55, 0.14, "#F6A24C", tilt_z=14)
    p.triangle([0.42, 1.98, 0.0], 0.5, 0.55, 0.14, "#F6A24C", tilt_z=-14)
    p.triangle([-0.42, 1.94, -0.075], 0.28, 0.32, 0.04, "#FFB6C4", tilt_z=14)
    p.triangle([0.42, 1.94, -0.075], 0.28, 0.32, 0.04, "#FFB6C4", tilt_z=-14)
    p.eyes(hc, hr, dx=0.32, dy=0.08, size=0.3)
    p.cheeks(hc, hr)
    p.ell([0.13, 0.09, 0.08], p.front(hc, hr, dy=-0.12), "#FF8FA8")
    p.ell([0.22, 0.22, 0.95], [0.25, 0.75, 0.85], "#F6A24C", rot(x=-35, y=20))
    p.ell([0.24, 0.24, 0.28], [0.36, 1.12, 1.15], "#D97E2A")


@pet("Puppy")
def puppy(p):
    hc, hr = classic_body(p, "#E9C899", "#FFF3E0")
    p.mirror(lambda s: p.ell([0.34, 0.78, 0.22], [s * 0.76, 1.32, 0.05], "#9C6B43", rot(z=s * 18)))
    p.ell([0.6, 0.38, 0.4], [0, 1.12, -0.6], "#FFF3E0")
    p.ell([0.2, 0.14, 0.12], [0, 1.24, -0.8], "#2A2230")
    p.ell([0.14, 0.18, 0.06], [0, 0.98, -0.78], "#FF7A8C")
    p.ell([0.38, 0.32, 0.1], [-0.32, 1.55, -0.6], "#9C6B43")  # пятно у глаза
    p.eyes(hc, hr, dx=0.32, dy=0.14, size=0.28)
    p.ell([0.2, 0.2, 0.6], [0, 0.85, 0.85], "#E9C899", rot(x=-50))


@pet("Bunny")
def bunny(p):
    hc, hr = classic_body(p, "#FBF7FF", "#FFFFFF")
    p.mirror(lambda s: p.ell([0.32, 1.05, 0.2], [s * 0.3, 2.35, 0.05], "#FBF7FF", rot(z=-s * 8)))
    p.mirror(lambda s: p.ell([0.17, 0.78, 0.06], [s * 0.3, 2.33, -0.04], "#FFB6CC", rot(z=-s * 8)))
    p.eyes(hc, hr, dx=0.3, dy=0.06, size=0.3)
    p.cheeks(hc, hr)
    p.ell([0.14, 0.1, 0.08], p.front(hc, hr, dy=-0.1), "#FF8FB0")
    p.mirror(lambda s: p.ell([0.12, 0.2, 0.06], [s * 0.07, 1.06, -0.64], "#FFFFFF"))
    p.ell([0.42, 0.42, 0.42], [0, 0.55, 0.8], "#FFFFFF")


@pet("Frog")
def frog(p):
    p.ell([1.4, 1.05, 1.35], [0, 0.55, 0.1], "#6CCB5F")
    p.ell([1.0, 0.65, 0.4], [0, 0.45, -0.38], "#C9F2B5")
    hc = [0, 1.25, -0.1]
    p.ell([1.65, 1.05, 1.3], hc, "#6CCB5F")
    for s in (-1, 1):
        p.ell([0.58, 0.58, 0.58], [s * 0.45, 1.78, -0.32], "#6CCB5F")
        p.ell([0.42, 0.42, 0.25], [s * 0.45, 1.8, -0.55], "#FFFFFF")
        p.ell([0.24, 0.28, 0.1], [s * 0.45, 1.8, -0.68], "#1B1A24")
        p.ell([0.08, 0.08, 0.04], [s * 0.45 + 0.05, 1.86, -0.73], "#FFFFFF", material="Neon")
    p.ell([0.7, 0.08, 0.06], [0, 1.0, -0.74], "#2E6B2A")
    p.cheeks([0, 1.2, -0.1], [0.82, 0.52, 0.65], dx=0.7, dy=-0.05)
    p.mirror(lambda s: p.ell([0.5, 0.22, 0.6], [s * 0.55, 0.11, -0.25], "#5AB34E"))


@pet("Penguin")
def penguin(p):
    p.ell([1.45, 2.0, 1.35], [0, 1.0, 0.05], "#2B3150")
    p.ell([1.05, 1.5, 0.6], [0, 0.88, -0.36], "#FFFFFF")
    hc, hr = [0, 1.38, -0.05], [0.72, 0.8, 0.67]
    p.eyes(hc, hr, dx=0.3, dy=0.18, size=0.26)
    p.cheeks(hc, hr, dx=0.6, dy=-0.05)
    p.ell([0.34, 0.18, 0.34], [0, 1.2, -0.72], "#FFA53A")
    p.mirror(lambda s: p.ell([0.2, 0.9, 0.5], [s * 0.74, 0.95, 0.05], "#2B3150", rot(z=s * 18)))
    p.mirror(lambda s: p.ell([0.42, 0.14, 0.55], [s * 0.3, 0.07, -0.25], "#FFA53A"))


@pet("Fox")
def fox(p):
    hc, hr = classic_body(p, "#F07A2A", "#FFFFFF", head_size=(1.6, 1.35, 1.35))
    p.triangle([-0.48, 2.05, 0.02], 0.55, 0.7, 0.14, "#F07A2A", tilt_z=16)
    p.triangle([0.48, 2.05, 0.02], 0.55, 0.7, 0.14, "#F07A2A", tilt_z=-16)
    p.triangle([-0.58, 2.29, -0.06], 0.22, 0.24, 0.06, "#3A2A2A", tilt_z=16)
    p.triangle([0.58, 2.29, -0.06], 0.22, 0.24, 0.06, "#3A2A2A", tilt_z=-16)
    p.ell([0.95, 0.55, 0.5], [0, 1.08, -0.5], "#FFFFFF")
    p.ell([0.17, 0.12, 0.1], [0, 1.18, -0.76], "#2A2230")
    p.eyes(hc, hr, dx=0.34, dy=0.14, size=0.27)
    p.ell([0.5, 0.5, 1.15], [0.2, 0.8, 0.95], "#F07A2A", rot(x=-38, y=18))
    p.ell([0.42, 0.42, 0.42], [0.36, 1.25, 1.35], "#FFFFFF")


@pet("Owl", glow=None)
def owl(p):
    p.ell([1.55, 1.85, 1.45], [0, 0.95, 0.05], "#8B6A4E")
    p.ell([1.05, 1.2, 0.5], [0, 0.78, -0.4], "#E8D3B5")
    hc, hr = [0, 1.35, -0.05], [0.78, 0.92, 0.72]
    p.mirror(lambda s: p.ell([0.6, 0.6, 0.2], [s * 0.3, 1.45, -0.66], "#F6E7CF"))
    p.mirror(lambda s: p.ell([0.38, 0.38, 0.12], [s * 0.3, 1.45, -0.75], "#F5C542"))
    p.mirror(lambda s: p.ell([0.22, 0.25, 0.08], [s * 0.3, 1.45, -0.81], "#1B1A24"))
    p.mirror(lambda s: p.ell([0.08, 0.08, 0.04], [s * 0.3 + 0.05, 1.51, -0.86], "#FFFFFF", material="Neon"))
    p.triangle([0, 1.18, -0.8], 0.2, 0.26, 0.14, "#F2A03D", tilt_x=180)
    p.triangle([-0.48, 1.95, 0.0], 0.34, 0.42, 0.12, "#6E513A", tilt_z=24)
    p.triangle([0.48, 1.95, 0.0], 0.34, 0.42, 0.12, "#6E513A", tilt_z=-24)
    p.mirror(lambda s: p.ell([0.28, 1.05, 0.75], [s * 0.78, 0.9, 0.1], "#6E513A", rot(z=s * 10)))
    p.mirror(lambda s: p.ell([0.36, 0.12, 0.32], [s * 0.28, 0.06, -0.3], "#F2A03D"))


@pet("Panda")
def panda(p):
    hc, hr = classic_body(p, "#FAFAFA", "#FFFFFF", head_size=(1.6, 1.4, 1.4))
    p.parts[0]["c"] = "#2A2A34"  # тело чёрное
    p.parts[2]["c"] = "#2A2A34"
    p.parts[3]["c"] = "#2A2A34"
    p.mirror(lambda s: p.ell([0.48, 0.48, 0.3], [s * 0.6, 1.98, 0.05], "#2A2A34"))
    p.mirror(lambda s: p.ell([0.42, 0.52, 0.18], [s * 0.32, 1.42, -0.6], "#2A2A34", rot(z=s * 25)))
    p.eyes(hc, hr, dx=0.33, dy=0.1, size=0.22, color="#FFFFFF", shine=False)
    p.mirror(lambda s: p.ell([0.12, 0.14, 0.06], [s * 0.3, 1.44, -0.72], "#1B1A24"))
    p.ell([0.22, 0.14, 0.1], p.front(hc, hr, dy=-0.12), "#2A2A34")
    p.cheeks(hc, hr)


@pet("Axolotl")
def axolotl(p):
    p.ell([1.3, 0.9, 1.6], [0, 0.48, 0.25], "#F7A8C8")
    hc, hr = [0, 1.05, -0.35], [0.85, 0.6, 0.62]
    p.ell([1.7, 1.2, 1.25], hc, "#F7A8C8")
    for s in (-1, 1):
        for i, (dy, a) in enumerate(((0.35, 35), (0.05, 5), (-0.25, -25))):
            p.ell([0.62, 0.16, 0.16], [s * 1.02, 1.05 + dy, -0.2], "#E2508E", rot(z=s * a))
    p.eyes(hc, hr, dx=0.42, dy=0.12, size=0.24)
    p.cheeks(hc, hr, dx=0.62, dy=-0.15)
    p.ell([0.5, 0.06, 0.06], [0, 0.88, -0.95], "#B8487A")
    p.ell([0.2, 0.75, 1.0], [0, 0.6, 1.25], "#FFC2DB", rot(x=-15))
    p.mirror(lambda s: p.ell([0.36, 0.18, 0.4], [s * 0.55, 0.09, 0.0], "#F7A8C8"))


@pet("Unicorn", glow="#FFE9A8", sparkles=True)
def unicorn(p):
    hc, hr = classic_body(p, "#FFFFFF", "#FFF6FB")
    p.triangle([-0.48, 1.97, 0.1], 0.36, 0.42, 0.12, "#FFFFFF", tilt_z=18)
    p.triangle([0.48, 1.97, 0.1], 0.36, 0.42, 0.12, "#FFFFFF", tilt_z=-18)
    # рог — вытянутый блестящий эллипсоид
    p.ell([0.2, 0.75, 0.2], [0, 2.25, -0.22], "#FFD54A", rot(x=-18), material="Neon")
    # грива-радуга
    for i, c in enumerate(("#FF8FB0", "#FFC36B", "#9FE38B", "#8CC8FF", "#C7A4FF")):
        p.ell([0.38, 0.38, 0.38], [0, 2.0 - i * 0.22, 0.45 + i * 0.12], c)
    p.eyes(hc, hr, dx=0.32, dy=0.06, size=0.28)
    p.cheeks(hc, hr)
    p.ell([0.6, 0.6, 0.6], [0, 0.75, 0.95], "#C7A4FF")


@pet("Dragon", glow="#B79BFF", sparkles=True)
def dragon(p):
    hc, hr = classic_body(p, "#7B5CFF", "#D8CCFF", head_size=(1.55, 1.35, 1.4))
    p.triangle([-0.4, 2.02, 0.12], 0.26, 0.5, 0.16, "#FFF1C9", tilt_z=20)
    p.triangle([0.4, 2.02, 0.12], 0.26, 0.5, 0.16, "#FFF1C9", tilt_z=-20)
    p.ell([0.75, 0.45, 0.45], [0, 1.15, -0.55], "#8F75FF")
    p.mirror(lambda s: p.ell([0.07, 0.07, 0.05], [s * 0.14, 1.2, -0.78], "#3B2A7A"))
    p.eyes(hc, hr, dx=0.34, dy=0.16, size=0.28, color="#1B1240")
    for s in (-1, 1):
        p.triangle([s * 0.85, 1.0, 0.45], 0.9, 0.9, 0.06, "#5BE0D0", tilt_z=s * -35, material="Glass", transparency=0.15)
    for i in range(3):
        p.triangle([0, 1.25 - i * 0.3, 0.72 + i * 0.12], 0.22, 0.28, 0.1, "#5BE0D0", tilt_x=-30 - i * 10)
    p.ell([0.3, 0.3, 1.0], [0, 0.45, 1.05], "#7B5CFF", rot(x=20))


@pet("Phoenix", glow="#FFB347", sparkles=True, fire=True)
def phoenix(p):
    p.ell([1.25, 1.35, 1.35], [0, 0.85, 0.15], "#FF8A2A", material="Neon")
    p.ell([0.8, 0.9, 0.4], [0, 0.78, -0.35], "#FFD36B")
    hc, hr = [0, 1.62, -0.1], [0.62, 0.6, 0.6]
    p.ell([1.24, 1.2, 1.2], hc, "#FFB347")
    p.eyes(hc, hr, dx=0.34, dy=0.1, size=0.24)
    p.triangle([0, 1.5, -0.68], 0.22, 0.26, 0.14, "#FFE08A", tilt_x=180)
    for i, (x, h) in enumerate(((-0.2, 0.55), (0, 0.75), (0.2, 0.55))):
        p.ell([0.16, h, 0.16], [x, 2.25 + h / 4, 0.05], "#FF5A3C", rot(z=-x * 60), material="Neon")
    for s in (-1, 1):
        p.ell([0.3, 1.0, 1.05], [s * 0.68, 1.0, 0.25], "#FF5A3C", rot(x=-15, z=s * 22), material="Neon")
        p.ell([0.2, 0.7, 0.75], [s * 0.82, 1.2, 0.35], "#FFD36B", rot(x=-15, z=s * 30))
    for i, a in enumerate((-22, 0, 22)):
        p.ell([0.22, 0.22, 1.15], [a / 60, 0.6, 1.1], "#FF8A2A", rot(x=25, y=a), material="Neon")


def egg_spec():
    p = Pet()
    c, r = [0, 1.05, 0], [0.85, 1.05, 0.85]
    p.ell([1.7, 2.1, 1.7], c, "#FFF4DE")
    # пятна лежат на поверхности яйца и повёрнуты по нормали
    for (yaw, pitch, size, color) in (
        (-28, 18, 0.5, "#FFC36B"),
        (30, -22, 0.44, "#8CC8FF"),
        (8, 48, 0.36, "#FF8FB0"),
        (-35, -40, 0.34, "#9FE38B"),
        (62, 20, 0.36, "#C7A4FF"),
        (-70, -5, 0.32, "#FF8FB0"),
    ):
        d = apply(rot(x=-pitch, y=-yaw), [0, 0, -1])
        pos = [c[i] + d[i] * r[i] * 0.97 for i in range(3)]
        p.ell([size, size, 0.12], pos, color, rot(x=-pitch, y=-yaw))
    return {"parts": p.parts, "glow": None, "sparkles": False, "fire": False}


def main():
    data = {"pets": PETS, "egg": egg_spec()}
    out = ROOT / "src" / "shared" / "PetSpecs.json"
    out.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    total = sum(len(v["parts"]) for v in PETS.values())
    print(f"{len(PETS)} pets, {total} parts -> {out.relative_to(ROOT)} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
