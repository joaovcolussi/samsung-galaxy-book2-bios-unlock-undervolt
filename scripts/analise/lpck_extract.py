import sys, os, re, zlib, hashlib
src, outdir = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
os.makedirs(outdir, exist_ok=True)
# nomes UTF-16 terminados em .gz
names = [(m.start(), m.group().decode('utf-16le')) for m in re.finditer(rb'(?:[A-Za-z0-9_\-\.]\x00){3,80}\.\x00g\x00z\x00', d)]
print("Entradas encontradas:")
for off, n in names:
    print(f"  0x{off:06X}  {n}")
results = []
for i, (off, n) in enumerate(names):
    start = d.find(b'\x1f\x8b\x08', off)
    if start < 0: continue
    dec = zlib.decompressobj(wbits=31)
    try:
        out = dec.decompress(d[start:start + 64 * 1024 * 1024])
    except Exception as e:
        print(f"  falha em {n}: {e}"); continue
    used = len(d[start:start + 64 * 1024 * 1024]) - len(dec.unused_data)
    fn = os.path.basename(n[:-3])
    open(os.path.join(outdir, fn), 'wb').write(out)
    results.append((fn, len(out), start, used, hashlib.sha256(out).hexdigest()[:16]))
print("\nExtraidos:")
for fn, sz, st, used, h in results:
    print(f"  {fn:40} {sz:>12,} bytes  (gzip em 0x{st:06X}, {used:,} compactado)  sha256={h}")
