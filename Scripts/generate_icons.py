#!/usr/bin/env python3
"""Pine rounded square with a cream hour mark. No external design tools."""

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PINE = (31, 111, 91, 255)
CREAM = (246, 241, 232, 255)


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def inside_round_rect(x: float, y: float, size: float, radius: float) -> bool:
    inset = size * 0.08
    left, right = inset, size - inset
    top, bottom = inset, size - inset
    if x < left or x > right or y < top or y > bottom:
        return False
    r = radius
    corners = (
        (left + r, top + r),
        (right - r, top + r),
        (left + r, bottom - r),
        (right - r, bottom - r),
    )
    for cx, cy in corners:
        if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
            return True
    inner_left, inner_right = left + r, right - r
    inner_top, inner_bottom = top + r, bottom - r
    return (inner_left <= x <= inner_right and top <= y <= bottom) or (
        left <= x <= right and inner_top <= y <= inner_bottom
    )


def hour_mark(x: float, y: float, size: float) -> bool:
    cx = size * 0.50
    cy = size * 0.52
    radius = size * 0.22
    stroke = max(size * 0.045, 1.0)
    dx, dy = x - cx, y - cy
    dist = (dx * dx + dy * dy) ** 0.5
    if abs(dist - radius) <= stroke * 0.55:
        return True
    hand = max(size * 0.035, 1.0)
    # A single hand toward 12, the hour.
    if abs(dx) <= hand * 0.55 and cy - radius * 0.72 <= y <= cy + hand:
        return True
    return False


def render(size: int) -> bytes:
    samples = 1 if size < 32 else 2
    buf = bytearray(size * size * 4)
    radius = size * 0.22
    for y in range(size):
        for x in range(size):
            pine_hits = 0
            cream_hits = 0
            for sy in range(samples):
                for sx in range(samples):
                    px = x + (sx + 0.5) / samples
                    py = y + (sy + 0.5) / samples
                    if not inside_round_rect(px, py, size, radius):
                        continue
                    pine_hits += 1
                    if hour_mark(px, py, size):
                        cream_hits += 1
            total = samples * samples
            if pine_hits == 0:
                continue
            cover = pine_hits / total
            cream = cream_hits / total
            if cream > 0:
                r, g, b = CREAM[0], CREAM[1], CREAM[2]
                alpha = int(255 * min(1.0, cream / cover) * cover)
            else:
                r, g, b = PINE[0], PINE[1], PINE[2]
                alpha = int(255 * cover)
            i = (y * size + x) * 4
            buf[i : i + 4] = bytes((r, g, b, alpha))
    return bytes(buf)


def main() -> None:
    app_sizes = {
        16: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-16.png",
        32: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-32.png",
        64: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-64.png",
        128: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-128.png",
        256: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-256.png",
        512: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-512.png",
        1024: ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/ios-1024.png",
    }
    for size, path in app_sizes.items():
        write_png(path, size, size, render(size))
    mac_1024 = ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-1024.png"
    mac_1024.write_bytes((ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/ios-1024.png").read_bytes())
    safari = ROOT / "Extensions/Safari/Resources/icons/icon-128.png"
    safari.parent.mkdir(parents=True, exist_ok=True)
    safari.write_bytes((ROOT / "Resources/Assets.xcassets/AppIcon.appiconset/mac-128.png").read_bytes())
    for size, name in ((128, "shield-128.png"), (256, "shield-256.png"), (384, "shield-384.png")):
        write_png(
            ROOT / "Extensions/ShieldConfiguration/Assets.xcassets/ShieldIcon.imageset" / name,
            size,
            size,
            render(size),
        )
    print("icons written")


if __name__ == "__main__":
    main()
