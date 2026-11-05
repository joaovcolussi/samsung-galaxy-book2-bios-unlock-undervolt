import sys, struct, math, collections
p = sys.argv[1]
d = open(p, 'rb').read()
pe = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, pe + 6)[0]
opt = struct.unpack_from('<H', d, pe + 20)[0]
sec = pe + 24 + opt
end = 0
print("Secoes:")
for i in range(nsec):
    name = d[sec:sec+8].rstrip(b'\0').decode(errors='replace')
    vsz, va, rsz, rptr = struct.unpack_from('<IIII', d, sec + 8)
    print(f"  {name:8} raw=0x{rptr:08X}..0x{rptr+rsz:08X} ({rsz:,} bytes)")
    end = max(end, rptr + rsz)
    sec += 40
# certificate table (security dir) - index 4 in data directories
magic = struct.unpack_from('<H', d, pe + 24)[0]
dd = pe + 24 + (96 if magic == 0x10b else 112)
cert_off, cert_sz = struct.unpack_from('<II', d, dd + 4 * 8)
print(f"Assinatura Authenticode: 0x{cert_off:X} ({cert_sz:,} bytes)")
print(f"Fim da imagem PE: 0x{end:X}; tamanho do arquivo: 0x{len(d):X}")
ov_end = cert_off if cert_off > end else len(d)
ov = d[end:ov_end]
print(f"Overlay: 0x{end:X}..0x{ov_end:X} ({len(ov):,} bytes)")
def entropy(b):
    if not b: return 0
    c = collections.Counter(b); n = len(b)
    return -sum(v/n*math.log2(v/n) for v in c.values())
print(f"Entropia overlay: {entropy(ov):.3f} bits/byte")
print("Primeiros 96 bytes do overlay:")
for i in range(0, 96, 16):
    chunk = ov[i:i+16]
    print(f"  {end+i:08X}  {chunk.hex(' ')}  {''.join(chr(c) if 32<=c<127 else '.' for c in chunk)}")
# largest section entropy
sec = pe + 24 + opt
for i in range(nsec):
    name = d[sec:sec+8].rstrip(b'\0').decode(errors='replace')
    vsz, va, rsz, rptr = struct.unpack_from('<IIII', d, sec + 8)
    if rsz > 1_000_000:
        print(f"Entropia secao {name}: {entropy(d[rptr:rptr+rsz]):.3f}")
    sec += 40
if len(sys.argv) > 2 and len(ov) > 0:
    open(sys.argv[2], 'wb').write(ov)
    print("Overlay salvo em", sys.argv[2])
