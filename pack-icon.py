#!/usr/bin/env python3
"""Package pre-sized PNGs as standard macOS ICNS chunks (no image editing)."""
from pathlib import Path
import struct

root = Path(__file__).resolve().parent
iconset = root / '.build/AppIcon.iconset'
entries = [('icp4', '16x16'), ('icp5', '32x32'), ('icp6', '32x32@2x'),
           ('ic07', '128x128'), ('ic08', '256x256'), ('ic09', '512x512'),
           ('ic10', '512x512@2x'), ('ic11', '16x16@2x'),
           ('ic12', '32x32@2x'), ('ic13', '128x128@2x'), ('ic14', '256x256@2x')]
chunks = []
for kind, name in entries:
    png = (iconset / f'icon_{name}.png').read_bytes()
    assert png.startswith(b'\x89PNG\r\n\x1a\n')
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(png) + 8) + png)
body = b''.join(chunks)
(root / 'Assets/AppIcon.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
