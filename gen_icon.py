#!/usr/bin/env python3
"""Generate pixel ghost app icon for GhostConnect."""
import os
import subprocess
import struct
import zlib

# 12x13 pixel ghost: 0=clear, 1=body(mauve), 2=eye white, 3=pupil(dark)
GHOST = [
    [0,0,0,0,1,1,1,1,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,0,0,0],
    [0,0,1,1,1,1,1,1,1,1,0,0],
    [0,1,1,1,1,1,1,1,1,1,1,0],
    [0,1,1,2,2,1,1,2,2,1,1,0],
    [0,1,1,3,2,1,1,3,2,1,1,0],
    [1,1,1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1,1,1],
    [1,1,1,1,1,1,1,1,1,1,1,1],
    [1,0,1,1,1,0,0,1,1,1,0,1],
    [1,0,0,1,0,0,0,0,1,0,0,1],
]

COLORS = {
    0: (30, 30, 46, 0),       # transparent (bg for blending)
    1: (203, 166, 247, 255),   # mauve
    2: (255, 255, 255, 255),   # white
    3: (30, 30, 46, 255),      # dark
}

BG = (30, 30, 46, 255)  # Catppuccin base

GHOST_W = len(GHOST[0])
GHOST_H = len(GHOST)


def create_png(size):
    """Create a PNG image as bytes (pure Python, no PIL needed)."""
    pixels = []
    pixel_size = max(1, int(size * 0.55) // max(GHOST_W, GHOST_H))
    ox = (size - GHOST_W * pixel_size) // 2
    oy = (size - GHOST_H * pixel_size) // 2

    for y in range(size):
        row = []
        for x in range(size):
            gx = (x - ox) // pixel_size if ox <= x < ox + GHOST_W * pixel_size else -1
            gy = (y - oy) // pixel_size if oy <= y < oy + GHOST_H * pixel_size else -1

            if 0 <= gx < GHOST_W and 0 <= gy < GHOST_H and GHOST[gy][gx] > 0:
                row.append(COLORS[GHOST[gy][gx]])
            else:
                row.append(BG)
        pixels.append(row)

    return encode_png(size, size, pixels)


def encode_png(width, height, pixels):
    """Encode RGBA pixels to PNG format."""
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))

    raw = b''
    for row in pixels:
        raw += b'\x00'  # filter none
        for r, g, b, a in row:
            raw += struct.pack('BBBB', r, g, b, a)

    idat = chunk(b'IDAT', zlib.compress(raw, 9))
    iend = chunk(b'IEND', b'')

    return sig + ihdr + idat + iend


def main():
    base = os.path.dirname(os.path.abspath(__file__))
    iconset = os.path.join(base, 'AppIcon.iconset')
    os.makedirs(iconset, exist_ok=True)

    specs = [
        ('icon_16x16.png', 16),
        ('icon_16x16@2x.png', 32),
        ('icon_32x32.png', 32),
        ('icon_32x32@2x.png', 64),
        ('icon_128x128.png', 128),
        ('icon_128x128@2x.png', 256),
        ('icon_256x256.png', 256),
        ('icon_256x256@2x.png', 512),
        ('icon_512x512.png', 512),
        ('icon_512x512@2x.png', 1024),
    ]

    for name, size in specs:
        path = os.path.join(iconset, name)
        with open(path, 'wb') as f:
            f.write(create_png(size))
        print(f'  {name} ({size}x{size})')

    icns_path = os.path.join(base, 'AppIcon.icns')
    subprocess.run(['iconutil', '-c', 'icns', iconset, '-o', icns_path], check=True)
    print(f'  -> AppIcon.icns')

    # Cleanup
    import shutil
    shutil.rmtree(iconset)


if __name__ == '__main__':
    main()
