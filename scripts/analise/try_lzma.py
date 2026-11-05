import sys, lzma, struct
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read()
print("props/dict/size:", d[0], hex(struct.unpack_from('<I', d, 1)[0]), hex(struct.unpack_from('<Q', d, 5)[0]))
def attempt(label, data):
    try:
        dec = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
        out = dec.decompress(data, max_length=64 * 1024 * 1024)
        print(f"{label}: OK, {len(out):,} bytes")
        return out
    except Exception as e:
        print(f"{label}: falhou ({e})")
        # parcial
        return None
out = attempt("LZMA padrao", d)
if out is None:
    # tentativa com tamanho desconhecido (0xFF..)
    patched = d[:5] + b'\xff' * 8 + d[13:]
    out = attempt("LZMA tamanho desconhecido", patched)
if out is None:
    # descompressao parcial em streaming para ver ate onde vai
    dec = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE)
    buf = b''
    try:
        for i in range(0, len(d), 4096):
            buf += dec.decompress(d[i:i+4096])
    except Exception as e:
        print(f"parcial: {len(buf):,} bytes antes do erro ({e})")
    out = buf
if out:
    open(dst, 'wb').write(out)
    print("primeiros bytes:", out[:64].hex(' '))
    print("_FVH em:", [hex(i) for i in range(0, min(len(out), 0x200000), 8) if out[i:i+4] == b'_FVH'][:5])
