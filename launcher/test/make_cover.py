#!/usr/bin/env python3
"""Writes a plain 600x900 gradient PNG (stdlib only) for the user-tiles test fixture."""
import struct, sys, zlib

W, H = 600, 900
rows = []
for y in range(H):
    row = bytearray([0])
    for x in range(W):
        t = y / H
        u = x / W
        row += bytes((int(40 + 180 * u), int(30 + 90 * (1 - t)), int(120 + 120 * t)))
    rows.append(bytes(row))
raw = b"".join(rows)

def chunk(kind, data):
    c = struct.pack(">I", len(data)) + kind + data
    return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
