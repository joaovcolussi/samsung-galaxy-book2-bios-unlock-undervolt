import sys, re, struct
d = open(sys.argv[1], 'rb').read()
print('tamanho', len(d), hex(len(d)))
for i in range(0, 0x400, 16):
    c = d[i:i+16]
    if any(c):
        print(f"{i:06X}  {c.hex(' ')}  {''.join(chr(x) if 32 <= x < 127 else '.' for x in c)}")
print('u32 no inicio:', [hex(x) for x in struct.unpack_from('<16I', d, 0)])
for sig, n in [(b'\x5d\x00\x00', 'LZMA'), (b'\x1f\x8b\x08', 'gzip'), (b'\x78\x9c', 'zlib'), (b'\x78\xda', 'zlib'),
               (b'BZh', 'bzip2'), (b'\xfd7zXZ', 'xz'), (b'\x28\xb5\x2f\xfd', 'zstd'), (b'_FVH', 'FVH'), (b'\x5a\xa5\xf0\x0f', 'IFD'),
               (b'LPCK', 'LPCK')]:
    o = [m.start() for m in re.finditer(re.escape(sig), d)]
    if o:
        print(f"{n:6} {len(o)}x  {[hex(x) for x in o[:6]]}")
