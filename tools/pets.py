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


def _norm(v):
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]


def _cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def basis_from_normal(n, spin=0):
    """Поворот, у которого локальная ось Z смотрит по нормали n (X — горизонтально, Y — вверх)."""
    z = _norm(n)
    up = [0, 1, 0] if abs(z[1]) < 0.97 else [0, 0, -1]
    x = _norm(_cross(up, z))
    y = _cross(z, x)
    if spin:
        a = math.radians(spin)
        c, s_ = math.cos(a), math.sin(a)
        x, y = [c * x[i] + s_ * y[i] for i in range(3)], [-s_ * x[i] + c * y[i] for i in range(3)]
    return [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]


class Surface:
    """Эллипсоид (голова/тело), на поверхность которого можно «приклеивать» детали."""

    def __init__(self, center, size):
        self.c = list(center)
        self.r = [size[0] / 2, size[1] / 2, size[2] / 2]

    def point(self, yaw, pitch):
        """yaw — вбок (0 = вперёд, -Z), pitch — вверх. Возвращает (точка, нормаль)."""
        ya, pa = math.radians(yaw), math.radians(pitch)
        d = [math.sin(ya) * math.cos(pa), math.sin(pa), -math.cos(ya) * math.cos(pa)]
        t = 1 / math.sqrt(sum((d[i] / self.r[i]) ** 2 for i in range(3)))
        p = [self.c[i] + d[i] * t for i in range(3)]
        n = _norm([(p[i] - self.c[i]) / self.r[i] ** 2 for i in range(3)])
        return p, n


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

    def cyl(self, size, pos, color, r=None, **kw):
        return self.add("cyl", size, pos, color, r, **kw)

    def mirror(self, fn):
        """fn(sign) вызывается для левой (-1) и правой (+1) стороны."""
        fn(-1)
        fn(1)
        return self

    def triangle(self, center, width, height, thick, color, tilt_z=0, tilt_x=0, tilt_y=0, **kw):
        """Равнобедренный треугольник (ухо, рог, шип) из двух клиньев, остриём вверх."""
        base = rot(x=tilt_x, y=tilt_y, z=tilt_z)
        for sign in (-1, 1):
            half = _mul(base, _ry(90 if sign < 0 else -90))
            offset = apply(base, [sign * width / 4, 0, 0])
            pos = [center[i] + offset[i] for i in range(3)]
            self.add("wedge", [thick, height, width / 2], pos, color, half, **kw)
        return self

    # --- детали на поверхности -------------------------------------------------

    def patch(self, surf, yaw, pitch, size, color, lift=0.0, spin=0, ox=0.0, oy=0.0, **kw):
        """Плоский эллипсоид, лежащий на поверхности (пятно, полоска, глаз, румянец)."""
        p, n = surf.point(yaw, pitch)
        b = basis_from_normal(n, spin)
        x = [b[0][0], b[1][0], b[2][0]]
        y = [b[0][1], b[1][1], b[2][1]]
        pos = [p[i] + n[i] * lift + x[i] * ox + y[i] * oy for i in range(3)]
        return self.ell(size, pos, color, b, **kw)

    def eye(self, surf, yaw, pitch, size, iris="#6B4BFF", base="#1B1A24", pupil="#0E0D14", slit=False, lift=0.0):
        """Мультяшный глаз: основа, радужка, зрачок и два блика. lift — поднять над поверхностью."""
        s, l = size, lift
        self.patch(surf, yaw, pitch, [s, s * 1.2, 0.12], base, lift=l)
        self.patch(surf, yaw, pitch, [s * 0.74, s * 0.66, 0.08], iris, lift=l + 0.035, oy=-s * 0.2)
        if slit:
            self.patch(surf, yaw, pitch, [s * 0.16, s * 0.62, 0.06], pupil, lift=l + 0.06, oy=-s * 0.08)
        else:
            self.patch(surf, yaw, pitch, [s * 0.42, s * 0.48, 0.06], pupil, lift=l + 0.06, oy=-s * 0.06)
        self.patch(surf, yaw, pitch, [s * 0.36, s * 0.36, 0.04], "#FFFFFF", lift=l + 0.085, ox=s * 0.17, oy=s * 0.26, material="Neon")
        self.patch(surf, yaw, pitch, [s * 0.16, s * 0.16, 0.04], "#FFFFFF", lift=l + 0.085, ox=-s * 0.16, oy=-s * 0.3, material="Neon")
        return self

    def eyes(self, surf, yaw=20, pitch=8, size=0.3, **kw):
        for sign in (-1, 1):
            self.eye(surf, sign * yaw, pitch, size, **kw)
        return self

    def blush(self, surf, yaw=40, pitch=-12, color="#FF9EB5", size=0.26):
        for sign in (-1, 1):
            self.patch(surf, sign * yaw, pitch, [size, size * 0.55, 0.06], color, lift=0.01, transparency=0.2)
        return self

    def mouth_w(self, surf, pitch=-22, color="#5A2F3A", width=0.11, yaw=0, lift=0.01):
        """Улыбка-«галочка» (ω). lift — поднять над мордочкой."""
        for sign in (-1, 1):
            self.patch(surf, yaw + sign * 4, pitch, [width, 0.035, 0.04], color, lift=lift, spin=-sign * 28)
        return self

    def whiskers(self, surf, pitch=-14, color="#FFFFFF"):
        for sign in (-1, 1):
            p, n = surf.point(sign * 36, pitch)
            for i, a in enumerate((12, 0, -12)):
                self.block([0.5, 0.025, 0.025], [p[0] + sign * 0.22, p[1] + i * -0.06 + 0.06, p[2] - 0.02], color, rot(z=sign * a, y=sign * -18))
        return self

    def paw_pads(self, center, color="#FF9EB5"):
        x, y, z = center
        self.ell([0.18, 0.12, 0.06], [x, y - 0.02, z - 0.2], color)
        for dx in (-0.09, 0, 0.09):
            self.ell([0.07, 0.07, 0.04], [x + dx, y + 0.07, z - 0.2], color)
        return self

    def collar(self, y, radius_x, radius_z, z, color, charm=None, charm_color="#FFD54A"):
        """Ошейник/шарф: плоский диск-кольцо на шее и подвеска спереди."""
        self.cyl([0.14, radius_x * 2, radius_z * 2], [0, y, z], color, rot(z=90))
        if charm == "bell":
            self.ell([0.24, 0.24, 0.24], [0, y - 0.14, z - radius_z - 0.04], charm_color, material="Metal")
            self.ell([0.12, 0.04, 0.04], [0, y - 0.18, z - radius_z - 0.15], "#9C7A1E")
        elif charm == "tag":
            self.cyl([0.05, 0.24, 0.24], [0, y - 0.16, z - radius_z - 0.03], charm_color, rot(y=90), material="Metal")
        return self


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


def classic_body(p, color, belly, paw=None, head_size=(1.5, 1.35, 1.35), head_y=1.35, pads=None):
    """Круглая голова + тело + лапки. Возвращает (голова, тело) как Surface."""
    body = Surface([0, 0.52, 0.2], [1.15, 1.02, 1.2])
    p.ell([1.15, 1.02, 1.2], body.c, color)
    p.patch(body, 0, -5, [0.72, 0.68, 0.2], belly, lift=-0.04)
    paw = paw or color
    for s in (-1, 1):
        p.ell([0.36, 0.3, 0.44], [s * 0.3, 0.14, -0.26], paw)  # передние лапки
        p.ell([0.4, 0.3, 0.46], [s * 0.42, 0.14, 0.42], paw)  # задние лапки
        if pads:
            p.paw_pads([s * 0.3, 0.14, -0.26], pads)
    head = Surface([0, head_y, -0.05], head_size)
    p.ell(list(head_size), head.c, color)
    return head, body


@pet("Kitten")
def kitten(p):
    orange, dark, cream = "#F6A24C", "#D9782A", "#FFE3C2"
    head, body = classic_body(p, orange, cream, pads="#FF9EB5")
    # ушки с розовой серединкой
    for s in (-1, 1):
        p.triangle([s * 0.42, 1.98, 0.0], 0.5, 0.55, 0.14, orange, tilt_z=-s * 14)
        p.triangle([s * 0.42, 1.94, -0.075], 0.28, 0.32, 0.04, "#FFB6C4", tilt_z=-s * 14)
    # полоски на лбу и спине
    for yaw, size in ((0, 0.34), (-16, 0.26), (16, 0.26)):
        p.patch(head, yaw, 50, [0.09, size, 0.06], dark, lift=0.0)
    for pitch in (40, 15, -10):
        p.patch(body, 180, pitch, [0.7, 0.1, 0.06], dark, lift=0.0)
    # мордочка
    p.patch(head, 0, -18, [0.62, 0.38, 0.22], cream, lift=-0.04)
    p.eyes(head, yaw=22, pitch=8, size=0.32, iris="#4CC16A")
    p.blush(head)
    p.patch(head, 0, -8, [0.15, 0.1, 0.08], "#FF7E9A", lift=0.06)
    p.mouth_w(head, pitch=-17, lift=0.08)
    p.whiskers(head)
    # ошейник с колокольчиком
    p.collar(0.88, 0.5, 0.48, -0.02, "#E8424F", charm="bell")
    # хвост с полосками
    p.ell([0.22, 0.22, 0.95], [0.25, 0.75, 0.85], orange, rot(x=-35, y=20))
    p.ell([0.24, 0.24, 0.28], [0.36, 1.12, 1.15], dark)
    p.ell([0.235, 0.235, 0.1], [0.3, 0.9, 1.0], dark, rot(x=-35, y=20))


@pet("Puppy")
def puppy(p):
    tan, brown, white = "#E9C899", "#9C6B43", "#FFF3E0"
    head, body = classic_body(p, tan, white, pads="#7A4E33")
    for s in (-1, 1):
        p.ell([0.34, 0.8, 0.22], [s * 0.76, 1.3, 0.05], brown, rot(z=s * 18))
        p.ell([0.2, 0.55, 0.06], [s * 0.74, 1.27, -0.06], "#B98458", rot(z=s * 18))
    p.patch(head, 0, -22, [0.66, 0.42, 0.26], white, lift=-0.05)
    p.patch(head, 22, 14, [0.42, 0.4, 0.06], brown)  # пятно вокруг глаза
    p.patch(body, 150, 30, [0.5, 0.42, 0.06], brown)  # пятно на спине
    p.eyes(head, yaw=22, pitch=10, size=0.3, iris="#8A5A2B")
    p.patch(head, 0, -10, [0.24, 0.16, 0.12], "#2A2230", lift=0.1)
    p.patch(head, 0, -6, [0.07, 0.05, 0.04], "#FFFFFF", lift=0.15, ox=0.04, material="Neon")
    p.mouth_w(head, pitch=-22, lift=0.09)
    p.patch(head, 0, -29, [0.14, 0.18, 0.06], "#FF7A8C", lift=0.07)  # язык
    p.blush(head, yaw=44, pitch=-14)
    p.collar(0.88, 0.5, 0.48, -0.02, "#3E8EF7", charm="tag")
    p.ell([0.2, 0.2, 0.62], [0, 0.85, 0.85], tan, rot(x=-50))
    p.ell([0.2, 0.2, 0.2], [0, 1.08, 1.06], white)


@pet("Bunny")
def bunny(p):
    white, pink = "#FBF7FF", "#FFB6CC"
    head, body = classic_body(p, white, "#FFFFFF", pads=pink)
    for s in (-1, 1):
        p.ell([0.32, 1.05, 0.2], [s * 0.3, 2.35, 0.05], white, rot(z=-s * 8))
        p.ell([0.17, 0.78, 0.06], [s * 0.3, 2.33, -0.04], pink, rot(z=-s * 8))
    # пушистые щёчки
    for s in (-1, 1):
        p.patch(head, s * 62, -18, [0.42, 0.34, 0.3], "#FFFFFF", lift=-0.06)
    p.eyes(head, yaw=21, pitch=6, size=0.31, iris="#B784FF")
    p.blush(head)
    p.patch(head, 0, -8, [0.15, 0.1, 0.08], "#FF8FB0", lift=0.02)
    p.mouth_w(head, pitch=-17, width=0.09)
    for s in (-1, 1):
        p.patch(head, s * 3.2, -27, [0.08, 0.13, 0.05], "#FFFFFF", lift=0.02)  # зубки
    # морковка в лапках
    p.ell([0.22, 0.22, 0.62], [0, 0.42, -0.52], "#FF8A2A", rot(x=-70))
    p.ell([0.05, 0.05, 0.6], [0, 0.42, -0.52], "#E06A16", rot(x=-70, y=90))
    for a in (-25, 0, 25):
        p.ell([0.08, 0.32, 0.08], [0, 0.72, -0.48], "#5CC45A", rot(z=a, x=-15))
    p.ell([0.44, 0.44, 0.44], [0, 0.55, 0.8], "#FFFFFF")


@pet("Frog")
def frog(p):
    green, light, spot = "#6CCB5F", "#C9F2B5", "#4FA645"
    body = Surface([0, 0.55, 0.1], [1.4, 1.05, 1.35])
    p.ell([1.4, 1.05, 1.35], body.c, green)
    p.patch(body, 0, -12, [1.0, 0.65, 0.26], light, lift=-0.05)
    head = Surface([0, 1.25, -0.1], [1.65, 1.05, 1.3])
    p.ell([1.65, 1.05, 1.3], head.c, green)
    for (yaw, pitch, size) in ((-45, 30, 0.22), (40, 40, 0.16), (60, 10, 0.18), (-62, 5, 0.14)):
        p.patch(head, yaw, pitch, [size, size, 0.06], spot)
    for (yaw, pitch, size) in ((150, 30, 0.26), (-150, 20, 0.2), (180, 50, 0.18)):
        p.patch(body, yaw, pitch, [size, size, 0.06], spot)
    for s in (-1, 1):
        eye = Surface([s * 0.45, 1.8, -0.32], [0.58, 0.58, 0.58])
        p.ell([0.58, 0.58, 0.58], eye.c, green)
        p.eye(eye, 0, 4, 0.4, iris="#F5C542", base="#FFFFFF", pupil="#1B1A24")
    p.patch(head, 0, -12, [0.8, 0.07, 0.06], "#2E6B2A", lift=0.0)  # улыбка
    p.blush(head, yaw=50, pitch=-6)
    # шляпка-кувшинка с цветком
    p.cyl([0.06, 0.95, 0.95], [0.25, 1.82, 0.15], "#3FA45A", rot(z=90, x=8))
    p.ell([0.22, 0.16, 0.22], [0.42, 1.9, 0.05], "#FF9EC6")
    p.ell([0.09, 0.09, 0.09], [0.42, 1.98, 0.05], "#FFE06B")
    for s in (-1, 1):
        p.ell([0.5, 0.22, 0.6], [s * 0.55, 0.11, -0.25], "#5AB34E")
        for dx in (-0.14, 0, 0.14):
            p.ell([0.12, 0.1, 0.12], [s * 0.55 + dx, 0.06, -0.56], "#5AB34E")


@pet("Penguin")
def penguin(p):
    navy, white, orange = "#2B3150", "#FFFFFF", "#FFA53A"
    body = Surface([0, 1.0, 0.05], [1.45, 2.0, 1.35])
    p.ell([1.45, 2.0, 1.35], body.c, navy)
    p.patch(body, 0, -12, [1.05, 1.35, 0.4], white, lift=-0.12)  # живот
    for s in (-1, 1):
        p.patch(body, s * 13, 20, [0.48, 0.52, 0.3], white, lift=-0.09)  # маска-сердечко
    head = Surface([0, 1.38, -0.05], [1.44, 1.6, 1.34])
    p.eyes(head, yaw=15, pitch=16, size=0.27, iris="#4EA7FF")
    p.blush(head, yaw=33, pitch=2)
    p.patch(head, 0, 3, [0.34, 0.14, 0.24], orange, lift=0.02)
    p.patch(head, 0, -1, [0.26, 0.09, 0.18], "#E8892A", lift=0.02)
    # шарф
    p.cyl([0.2, 1.32, 1.24], [0, 1.0, 0.05], "#E8424F", rot(z=90))
    p.ell([0.26, 0.55, 0.12], [0.34, 0.74, -0.6], "#E8424F", rot(z=-14))
    p.ell([0.27, 0.07, 0.13], [0.38, 0.55, -0.6], "#FFFFFF", rot(z=-14))
    for s in (-1, 1):
        p.ell([0.2, 0.9, 0.5], [s * 0.74, 0.95, 0.05], navy, rot(z=s * 18))
        p.ell([0.42, 0.14, 0.55], [s * 0.3, 0.07, -0.25], orange)
        for dx in (-0.12, 0.12):
            p.ell([0.12, 0.08, 0.12], [s * 0.3 + dx, 0.05, -0.52], orange)


@pet("Fox")
def fox(p):
    orange, white, dark = "#F07A2A", "#FFFFFF", "#3A2A2A"
    head, body = classic_body(p, orange, white, paw=dark, head_size=(1.6, 1.35, 1.35))
    for s in (-1, 1):
        p.triangle([s * 0.48, 2.05, 0.02], 0.55, 0.7, 0.14, orange, tilt_z=-s * 16)
        p.triangle([s * 0.47, 2.0, -0.06], 0.3, 0.38, 0.04, "#FFD9C2", tilt_z=-s * 16)
        p.triangle([s * 0.58, 2.29, -0.03], 0.22, 0.24, 0.16, dark, tilt_z=-s * 16)
        # белые щёчки-пушки
        p.patch(head, s * 66, -16, [0.42, 0.3, 0.3], white, lift=-0.06, spin=-s * 20)
    p.patch(head, 0, -22, [0.74, 0.42, 0.26], white, lift=-0.05)
    p.eyes(head, yaw=22, pitch=12, size=0.29, iris="#F5A623", slit=False)
    p.patch(head, 0, -11, [0.2, 0.14, 0.1], "#2A2230", lift=0.08)
    p.patch(head, 0, -7, [0.06, 0.05, 0.04], "#FFFFFF", lift=0.13, ox=0.03, material="Neon")
    p.mouth_w(head, pitch=-21, lift=0.08)
    p.blush(head, yaw=38, pitch=-6)
    p.ell([0.5, 0.5, 1.15], [0.2, 0.8, 0.95], orange, rot(x=-38, y=18))
    p.ell([0.44, 0.44, 0.44], [0.36, 1.25, 1.35], white)


@pet("Owl")
def owl(p):
    brown, light, dark = "#8B6A4E", "#E8D3B5", "#6E513A"
    body = Surface([0, 0.95, 0.05], [1.55, 1.85, 1.45])
    p.ell([1.55, 1.85, 1.45], body.c, brown)
    p.patch(body, 0, -20, [1.05, 1.05, 0.3], light, lift=-0.08)
    # перья на груди: ряды «галочек»
    for row, pitch in enumerate((-8, -22, -36)):
        for yaw in (-20, 0, 20) if row != 1 else (-10, 10):
            p.patch(body, yaw, pitch, [0.16, 0.07, 0.05], "#B89770", lift=0.0, spin=30)
            p.patch(body, yaw + 4, pitch, [0.16, 0.07, 0.05], "#B89770", lift=0.0, spin=-30)
    face = Surface([0, 1.45, -0.05], [1.5, 1.4, 1.4])
    for s in (-1, 1):
        p.patch(face, s * 15, 2, [0.66, 0.66, 0.2], "#F6E7CF", lift=0.0)
        p.eye(face, s * 15, 2, 0.46, iris="#F59E2A", lift=0.11)
        p.triangle([s * 0.48, 1.95, 0.0], 0.34, 0.44, 0.12, dark, tilt_z=-s * 24)
    p.triangle([0, 1.2, -0.8], 0.2, 0.28, 0.14, "#F2A03D", tilt_x=180)
    for s in (-1, 1):
        p.ell([0.28, 1.05, 0.75], [s * 0.78, 0.9, 0.1], dark, rot(z=s * 10))
        for i in range(3):
            p.ell([0.22, 0.42, 0.18], [s * (0.86 + i * 0.02), 0.52 - i * 0.02, -0.12 + i * 0.22], "#B89770", rot(z=s * 10))
        for dx in (-0.1, 0, 0.1):
            p.ell([0.09, 0.14, 0.2], [s * 0.28 + dx, 0.06, -0.36], "#F2A03D")


@pet("Panda")
def panda(p):
    white, black = "#FAFAFA", "#2A2A34"
    head, body = classic_body(p, white, "#FFFFFF", paw=black, head_size=(1.6, 1.4, 1.4), pads="#6A6A78")
    p.parts[0]["c"] = black  # тело чёрное, животик белый
    for s in (-1, 1):
        p.ell([0.48, 0.48, 0.3], [s * 0.6, 1.98, 0.05], black)
        p.ell([0.26, 0.26, 0.1], [s * 0.6, 1.97, -0.08], "#55555F")
        p.patch(head, s * 21, 6, [0.42, 0.54, 0.1], black, spin=-s * 28)
        p.eye(head, s * 21, 9, 0.24, iris="#7A5A3A", base="#FFFFFF", pupil="#1B1A24")
    p.patch(head, 0, -10, [0.24, 0.15, 0.1], black, lift=0.02)
    p.mouth_w(head, pitch=-20)
    p.blush(head)
    # бамбук в лапках
    for i in range(3):
        p.cyl([0.4, 0.16, 0.16], [0.0, 0.32 + i * 0.4, -0.5], "#7CC35A", rot(z=90, x=-12))
        p.cyl([0.05, 0.19, 0.19], [0.0, 0.52 + i * 0.4, -0.54], "#5B9E3E", rot(z=90, x=-12))
    p.ell([0.1, 0.38, 0.06], [0.16, 1.32, -0.6], "#5CC45A", rot(z=-35))
    p.ell([0.1, 0.32, 0.06], [-0.12, 1.28, -0.6], "#5CC45A", rot(z=30))


@pet("Axolotl")
def axolotl(p):
    pink, deep, light = "#F7A8C8", "#E2508E", "#FFC2DB"
    body = Surface([0, 0.48, 0.25], [1.3, 0.9, 1.6])
    p.ell([1.3, 0.9, 1.6], body.c, pink)
    head = Surface([0, 1.05, -0.35], [1.7, 1.2, 1.25])
    p.ell([1.7, 1.2, 1.25], head.c, pink)
    for (yaw, pitch, size) in ((-40, 35, 0.12), (30, 45, 0.1), (55, 20, 0.08), (-58, 10, 0.09)):
        p.patch(head, yaw, pitch, [size, size, 0.05], "#E98AB2")
    for (yaw, pitch) in ((160, 40), (-160, 30), (180, 10)):
        p.patch(body, yaw, pitch, [0.12, 0.12, 0.05], "#E98AB2")
    for s in (-1, 1):
        for dy, a in ((0.35, 35), (0.05, 5), (-0.25, -25)):
            base = [s * 1.02, 1.05 + dy, -0.2]
            p.ell([0.62, 0.16, 0.16], base, deep, rot(z=s * a))
            for k in (-1, 1):
                p.ell([0.2, 0.09, 0.09], [base[0] + s * 0.12, base[1] + k * 0.08, base[2]], "#F06BA5", rot(z=s * a + k * 40))
    p.eyes(head, yaw=26, pitch=10, size=0.25, iris="#3A2340")
    p.blush(head, yaw=40, pitch=-10)
    p.patch(head, 0, -14, [0.5, 0.06, 0.05], "#B8487A", lift=0.0)
    p.ell([0.12, 0.72, 1.0], [0, 0.62, 1.25], light, rot(x=-15), transparency=0.1)
    p.ell([0.18, 0.5, 0.85], [0, 0.55, 1.18], pink, rot(x=-15))
    for s in (-1, 1):
        for z in (-0.05, 0.6):
            p.ell([0.3, 0.16, 0.32], [s * 0.58, 0.09, z], pink)
            for dx in (-0.08, 0.08):
                p.ell([0.06, 0.06, 0.1], [s * 0.6 + dx, 0.05, z - 0.18], pink)


@pet("Unicorn", glow="#FFE9A8", sparkles=True)
def unicorn(p):
    white, gold = "#FFFFFF", "#FFD54A"
    head, body = classic_body(p, white, "#FFF6FB", paw=gold)
    for s in (-1, 1):
        p.triangle([s * 0.48, 1.97, 0.1], 0.36, 0.42, 0.12, white, tilt_z=-s * 18)
        p.triangle([s * 0.48, 1.94, 0.03], 0.2, 0.24, 0.04, "#FFC6DE", tilt_z=-s * 18)
    # витой рог: сужающиеся кольца
    for i in range(5):
        w = 0.24 - i * 0.04
        p.ell([w, 0.22, w], [0, 2.02 + i * 0.16, -0.28 - i * 0.04], gold if i % 2 == 0 else "#FFE58F", material="Neon")
    # грива-радуга на затылке и хвост
    colors = ("#FF8FB0", "#FFC36B", "#9FE38B", "#8CC8FF", "#C7A4FF")
    for i, c in enumerate(colors):
        p.ell([0.36, 0.36, 0.36], [0.05 * (i % 2), 2.02 - i * 0.22, 0.42 + i * 0.12], c)
        p.ell([0.2, 0.48, 0.2], [0, 1.0 - i * 0.07, 0.9 + i * 0.06], c, rot(x=-30 + i * 12))
    p.ell([0.34, 0.2, 0.3], [-0.12, 2.07, -0.3], "#FF8FB0", rot(z=20))  # чёлка
    p.eyes(head, yaw=22, pitch=6, size=0.3, iris="#9B6BFF")
    for s in (-1, 1):  # реснички
        for k, a in enumerate((-30, 0, 30)):
            p.patch(head, s * (28 + k * 3), 20, [0.03, 0.12, 0.03], "#1B1A24", lift=0.02, spin=s * a)
    p.blush(head)
    p.mouth_w(head, pitch=-20)
    p.patch(head, -44, -4, [0.16, 0.16, 0.04], gold, lift=0.01, material="Neon")  # звёздочка-метка


@pet("Dragon", glow="#B79BFF", sparkles=True)
def dragon(p):
    purple, belly, teal, horn = "#7B5CFF", "#D8CCFF", "#5BE0D0", "#FFF1C9"
    head, body = classic_body(p, purple, belly, head_size=(1.55, 1.35, 1.4))
    for pitch in (18, 4, -10, -24):  # полоски на животе
        p.patch(body, 0, pitch, [0.62 - abs(pitch) * 0.004, 0.05, 0.05], "#B6A5FF", lift=0.12)
    for s in (-1, 1):
        p.triangle([s * 0.4, 2.0, 0.12], 0.26, 0.46, 0.16, horn, tilt_z=-s * 20, tilt_x=-15)
        p.triangle([s * 0.55, 2.22, 0.25], 0.14, 0.24, 0.1, horn, tilt_z=-s * 35, tilt_x=-35)
    p.patch(head, 0, -16, [0.78, 0.48, 0.3], "#8F75FF", lift=-0.05)
    for s in (-1, 1):
        p.patch(head, s * 6, -10, [0.07, 0.05, 0.04], "#3B2A7A", lift=0.11)
        p.patch(head, s * 7, -30, [0.06, 0.1, 0.04], "#FFFFFF", lift=0.0)  # клычки
    p.eyes(head, yaw=22, pitch=12, size=0.3, iris="#F5C542", slit=True)
    p.blush(head, yaw=42, pitch=-8, color="#FF9EDB")
    for s in (-1, 1):
        p.triangle([s * 0.85, 1.0, 0.45], 0.9, 0.9, 0.06, teal, tilt_z=s * -35, material="Glass", transparency=0.15)
    for i in range(4):
        p.triangle([0, 1.95 - i * 0.38, 0.55 + i * 0.16], 0.22, 0.28, 0.1, teal, tilt_x=-20 - i * 18)
    p.ell([0.3, 0.3, 1.0], [0, 0.45, 1.05], purple, rot(x=20))
    p.triangle([0, 0.3, 1.6], 0.36, 0.4, 0.08, teal, tilt_x=-90)
    for s in (-1, 1):
        for dx in (-0.1, 0.1):
            p.ell([0.07, 0.07, 0.12], [s * 0.3 + dx, 0.08, -0.5], horn)


@pet("Phoenix", glow="#FFB347", sparkles=True, fire=True)
def phoenix(p):
    body = Surface([0, 0.85, 0.15], [1.25, 1.35, 1.35])
    p.ell([1.25, 1.35, 1.35], body.c, "#FF8A2A", material="Neon")
    p.patch(body, 0, -10, [0.8, 0.9, 0.3], "#FFD36B", lift=-0.06)
    for pitch in (0, -20):
        for yaw in (-14, 14):
            p.patch(body, yaw, pitch, [0.16, 0.1, 0.05], "#FFB347", lift=0.0, spin=yaw * 2)
    head = Surface([0, 1.62, -0.1], [1.24, 1.2, 1.2])
    p.ell([1.24, 1.2, 1.2], head.c, "#FFB347")
    p.eyes(head, yaw=24, pitch=8, size=0.25, iris="#FF5A3C")
    for s in (-1, 1):
        p.patch(head, s * 40, -6, [0.16, 0.06, 0.04], "#FF5A3C", lift=0.01, spin=-s * 15)
    p.triangle([0, 1.5, -0.68], 0.22, 0.26, 0.14, "#FFE08A", tilt_x=180)
    # хохолок-веер
    for i, (x, h, c) in enumerate(((-0.3, 0.45, "#FFD36B"), (-0.15, 0.62, "#FF8A2A"), (0, 0.78, "#FF5A3C"), (0.15, 0.62, "#FF8A2A"), (0.3, 0.45, "#FFD36B"))):
        p.ell([0.15, h, 0.15], [x, 2.22 + h / 4, 0.05], c, rot(z=-x * 80), material="Neon")
    # крылья в три слоя
    for s in (-1, 1):
        for i, (c, w) in enumerate((("#FF5A3C", 1.0), ("#FF8A2A", 0.8), ("#FFD36B", 0.6))):
            p.ell([0.26, w, 1.05 - i * 0.15], [s * (0.68 + i * 0.07), 1.0 + i * 0.14, 0.25 + i * 0.06], c, rot(x=-15, z=s * (22 + i * 8)), material="Neon" if i == 0 else "SmoothPlastic")
    # хвостовые перья с огоньками на концах
    for a in (-32, -16, 0, 16, 32):
        p.ell([0.2, 0.2, 1.25], [a / 60, 0.58, 1.12], "#FF8A2A", rot(x=25, y=a), material="Neon")
        tip = apply(rot(x=25, y=a), [0, 0, 0.62])
        p.ell([0.26, 0.26, 0.3], [a / 60 + tip[0], 0.58 + tip[1], 1.12 + tip[2]], "#FFE08A", material="Neon")
    for s in (-1, 1):
        for dx in (-0.08, 0.08):
            p.ell([0.07, 0.16, 0.07], [s * 0.25 + dx, 0.12, -0.15], "#E0A23A")


@pet("MoonFox", glow="#9FC4FF", sparkles=True)
def moon_fox(p):
    """Эксклюзив сезонного пропуска «Глава 1»: тёмно-синий лис со звёздами."""
    navy, star, light = "#2C3A7A", "#FFE08A", "#AFC8FF"
    head, body = classic_body(p, navy, light, paw="#1E2858", head_size=(1.6, 1.35, 1.35))
    for s in (-1, 1):
        p.triangle([s * 0.48, 2.05, 0.02], 0.55, 0.7, 0.14, navy, tilt_z=-s * 16)
        p.triangle([s * 0.47, 2.0, -0.06], 0.3, 0.38, 0.04, "#6F86E8", tilt_z=-s * 16)
        p.triangle([s * 0.58, 2.29, -0.03], 0.22, 0.24, 0.16, star, tilt_z=-s * 16, material="Neon")
        p.patch(head, s * 66, -16, [0.42, 0.3, 0.3], light, lift=-0.06, spin=-s * 20)
    p.patch(head, 0, -22, [0.74, 0.42, 0.26], light, lift=-0.05)
    p.eyes(head, yaw=22, pitch=12, size=0.29, iris="#7FE3FF")
    p.patch(head, 0, -11, [0.2, 0.14, 0.1], "#141A3A", lift=0.08)
    p.mouth_w(head, pitch=-21, lift=0.08, color="#141A3A")
    p.blush(head, yaw=38, pitch=-6, color="#9FB6FF")
    # месяц на лбу и звёзды на теле
    p.patch(head, 0, 44, [0.28, 0.28, 0.06], star, material="Neon")
    p.patch(head, 6, 48, [0.24, 0.24, 0.07], navy, lift=0.01)
    for (yaw, pitch) in ((150, 30), (-140, 10), (175, -10), (120, -20)):
        p.patch(body, yaw, pitch, [0.1, 0.1, 0.05], star, material="Neon")
    p.ell([0.5, 0.5, 1.15], [0.2, 0.8, 0.95], navy, rot(x=-38, y=18))
    p.ell([0.44, 0.44, 0.44], [0.36, 1.25, 1.35], star, material="Neon")
    for t in (0.3, 0.55):
        p.ell([0.08, 0.08, 0.08], [0.2 + t * 0.2, 0.8 + t * 0.5, 0.95 + t * 0.45], star, material="Neon")


def egg_spec():
    p = Pet()
    egg = Surface([0, 1.05, 0], [1.7, 2.1, 1.7])
    p.ell([1.7, 2.1, 1.7], egg.c, "#FFF4DE")
    # пятна разных цветов
    for (yaw, pitch, size, color) in (
        (-28, 18, 0.5, "#FFC36B"),
        (30, -22, 0.44, "#8CC8FF"),
        (8, 48, 0.36, "#FF8FB0"),
        (-35, -40, 0.34, "#9FE38B"),
        (62, 20, 0.36, "#C7A4FF"),
        (-70, -5, 0.32, "#FF8FB0"),
    ):
        p.patch(egg, yaw, pitch, [size, size, 0.12], color, lift=-0.02)
    # пояс-зигзаг
    for i in range(18):
        yaw = -90 + i * 10
        p.patch(egg, yaw, -4 + (6 if i % 2 else -6), [0.16, 0.05, 0.05], "#E8B04A", lift=0.0, spin=45 if i % 2 else -45)
    return {"parts": p.parts, "glow": None, "sparkles": False, "fire": False}


def main():
    data = {"pets": PETS, "egg": egg_spec()}
    out = ROOT / "src" / "shared" / "PetSpecs.json"
    out.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    total = sum(len(v["parts"]) for v in PETS.values())
    print(f"{len(PETS)} pets, {total} parts -> {out.relative_to(ROOT)} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
