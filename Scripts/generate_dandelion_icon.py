import math
import random
import struct
import zlib
from pathlib import Path

SRC = Path("Assets/Gemini_Generated_Image_rcyqq2rcyqq2rcyq.png")
OUT_SVG = Path("Assets/DandelionSeedIcon_code.svg")
OUT_PNG = Path("Assets/DandelionSeedIcon_code.png")

WIDTH = 1024
HEIGHT = 1024


def decode_png_rgba(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a png")
    pos = 8
    idat = bytearray()
    width = height = None
    bit_depth = color_type = None
    while pos < len(data):
        length = int.from_bytes(data[pos:pos + 4], "big")
        pos += 4
        ctype = data[pos:pos + 4]
        pos += 4
        chunk = data[pos:pos + length]
        pos += length
        pos += 4
        if ctype == b"IHDR":
            width, height, bit_depth, color_type, _c, _f, _i = struct.unpack(">IIBBBBB", chunk
            )
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(idat)
    if color_type != 6 or bit_depth != 8:
        raise ValueError("unsupported png format")
    bpp = 4
    stride = width * bpp
    rows = []
    idx = 0
    prev = bytearray(stride)
    for _y in range(height):
        f = raw[idx]
        idx += 1
        row = bytearray(raw[idx:idx + stride])
        idx += stride
        if f == 0:
            pass
        elif f == 1:
            for i in range(bpp, stride):
                row[i] = (row[i] + row[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                row[i] = (row[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                left = row[i - bpp] if i >= bpp else 0
                up = prev[i]
                row[i] = (row[i] + ((left + up) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = row[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa = abs(p - a)
                pb = abs(p - b)
                pc = abs(p - c)
                if pa <= pb and pa <= pc:
                    pr = a
                elif pb <= pc:
                    pr = b
                else:
                    pr = c
                row[i] = (row[i] + pr) & 0xFF
        else:
            raise ValueError("unknown filter")
        rows.append(row)
        prev = row
    return width, height, rows


def brightness_at(rows, x, y):
    if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
        return 0.0
    i = int(x) * 4
    row = rows[int(y)]
    r, g, b = row[i], row[i + 1], row[i + 2]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def estimate_center(rows):
    max_b = 0.0
    for y in range(HEIGHT):
        row = rows[y]
        for x in range(WIDTH):
            i = x * 4
            r, g, b = row[i], row[i + 1], row[i + 2]
            bval = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if bval > max_b:
                max_b = bval
    threshold = max_b * 0.90
    bright = []
    for y in range(HEIGHT):
        row = rows[y]
        for x in range(WIDTH):
            i = x * 4
            r, g, b = row[i], row[i + 1], row[i + 2]
            bval = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if bval >= threshold:
                bright.append((bval, x, y))
    sum_w = sum(p[0] for p in bright) or 1.0
    cx = sum(p[0] * p[1] for p in bright) / sum_w
    cy = sum(p[0] * p[2] for p in bright) / sum_w
    return cx, cy


def estimate_seed(rows, cx, cy):
    points = []
    for y in range(int(cy), HEIGHT):
        row = rows[y]
        for x in range(0, int(cx)):
            i = x * 4
            r, g, b = row[i], row[i + 1], row[i + 2]
            bval = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if 45 < bval < 140 and r > g > b and (r - b) > 15:
                dx = x - cx
                dy = y - cy
                if 170 < math.hypot(dx, dy) < 460:
                    points.append((x, y))
    if not points:
        return cx - 90, cy + 210
    sx = sum(p[0] for p in points) / len(points)
    sy = sum(p[1] for p in points) / len(points)
    return sx, sy


def sample_angle(rng):
    # Weighted clusters to mimic the reference fan (mostly right and slightly upward)
    roll = rng.random()
    if roll < 0.5:
        return rng.gauss(15, 14)
    if roll < 0.9:
        return rng.gauss(70, 22)
    return rng.gauss(115, 12)


def length_for_angle(rng, ang):
    # Longer in the mid-right fan, shorter near extremes
    bell = math.exp(-((ang - 80) / 45) ** 2)
    base = 150 + 230 * bell
    return base + rng.uniform(-14, 18)


def build_svg(cx, cy, sx, sy, filaments):
    svg = []
    svg.append('<?xml version="1.0" encoding="UTF-8"?>')
    svg.append('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">')
    svg.append('  <defs>')
    svg.append('    <radialGradient id="glow" cx="50%" cy="50%" r="50%">')
    svg.append('      <stop offset="0%" stop-color="#f7efe2" stop-opacity="0.95"/>')
    svg.append('      <stop offset="38%" stop-color="#d7b486" stop-opacity="0.55"/>')
    svg.append('      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>')
    svg.append('    </radialGradient>')
    svg.append('    <filter id="softGlow" x="-50%" y="-50%" width="200%" height="200%">')
    svg.append('      <feGaussianBlur stdDeviation="18" result="blur"/>')
    svg.append('      <feMerge>')
    svg.append('        <feMergeNode in="blur"/>')
    svg.append('        <feMergeNode in="SourceGraphic"/>')
    svg.append('      </feMerge>')
    svg.append('    </filter>')
    svg.append('    <linearGradient id="seedGrad" x1="0" y1="0" x2="1" y2="1">')
    svg.append('      <stop offset="0%" stop-color="#8a6b46"/>')
    svg.append('      <stop offset="55%" stop-color="#5a4026"/>')
    svg.append('      <stop offset="100%" stop-color="#3b2818"/>')
    svg.append('    </linearGradient>')
    svg.append('  </defs>')
    svg.append('  <rect width="100%" height="100%" fill="#0b0b0b"/>')
    svg.append(f'  <circle cx="{cx:.2f}" cy="{cy:.2f}" r="135" fill="url(#glow)" filter="url(#softGlow)"/>')
    svg.append(f'  <circle cx="{cx:.2f}" cy="{cy:.2f}" r="18" fill="#f8f1e6" opacity="0.35"/>')
    svg.append('  <g fill="none" stroke-linecap="round" stroke-linejoin="round">')
    for d, stroke, w, o in filaments:
        svg.append(f'    <path d="{d}" stroke="{stroke}" stroke-width="{w:.2f}" opacity="{o:.2f}"/>')
    svg.append('  </g>')
    svg.append(f'  <circle cx="{cx:.2f}" cy="{cy:.2f}" r="4" fill="#f8efe3"/>')
    stem_d = f"M {cx:.2f} {cy:.2f} C {cx-35:.2f} {cy+95:.2f} {sx+18:.2f} {sy-70:.2f} {sx:.2f} {sy:.2f}"
    svg.append(f'  <path d="{stem_d}" fill="none" stroke="#cdb68c" stroke-width="2" stroke-linecap="round"/>')
    svg.append(f'  <ellipse cx="{sx:.2f}" cy="{sy:.2f}" rx="16" ry="36" fill="url(#seedGrad)" transform="rotate(-20 {sx:.2f} {sy:.2f})"/>')
    svg.append('</svg>')
    return "\n".join(svg)


def main():
    width, height, rows = decode_png_rgba(SRC)
    if width != WIDTH or height != HEIGHT:
        raise ValueError("unexpected size")

    cx, cy = estimate_center(rows)
    sx, sy = estimate_seed(rows, cx, cy)

    rng = random.Random(23)
    filaments = []
    filament_count = 95
    inner_count = 30

    for _ in range(filament_count):
        ang = sample_angle(rng)
        if ang < -5 or ang > 150:
            continue
        length = length_for_angle(rng, ang)
        if length < 120:
            continue

        rad = math.radians(ang)
        dx = math.cos(rad)
        dy = math.sin(rad)
        nx = -dy
        ny = dx

        bend = rng.uniform(-10, 8)
        cx1 = cx + dx * (length * 0.52) + nx * bend
        cy1 = cy + dy * (length * 0.52) + ny * bend
        x1 = cx + dx * length
        y1 = cy + dy * length

        warm = 0.0
        if 70 <= ang <= 150:
            warm = (ang - 70) / 80.0
        r = int(245 - 25 * warm)
        g = int(242 - 70 * warm)
        b = int(235 - 120 * warm)
        stroke = f"#{r:02x}{g:02x}{b:02x}"
        w = rng.uniform(0.6, 1.0)
        o = rng.uniform(0.55, 0.9)
        d = f"M {cx:.2f} {cy:.2f} Q {cx1:.2f} {cy1:.2f} {x1:.2f} {y1:.2f}"
        filaments.append((d, stroke, w, o))

    # inner soft burst (shorter filaments near the core)
    for _ in range(inner_count):
        ang = rng.gauss(60, 25)
        if ang < 0 or ang > 140:
            continue
        length = rng.uniform(55, 120)
        rad = math.radians(ang)
        dx = math.cos(rad)
        dy = math.sin(rad)
        nx = -dy
        ny = dx
        bend = rng.uniform(-6, 6)
        cx1 = cx + dx * (length * 0.55) + nx * bend
        cy1 = cy + dy * (length * 0.55) + ny * bend
        x1 = cx + dx * length
        y1 = cy + dy * length
        stroke = "#f6efe3"
        w = rng.uniform(0.6, 0.9)
        o = rng.uniform(0.65, 0.95)
        d = f"M {cx:.2f} {cy:.2f} Q {cx1:.2f} {cy1:.2f} {x1:.2f} {y1:.2f}"
        filaments.append((d, stroke, w, o))

    svg = build_svg(cx, cy, sx, sy, filaments)
    OUT_SVG.write_text(svg)
    print(f"wrote {OUT_SVG}")
    print(f"center {cx:.2f},{cy:.2f} seed {sx:.2f},{sy:.2f} filaments {len(filaments)}")


if __name__ == "__main__":
    main()
