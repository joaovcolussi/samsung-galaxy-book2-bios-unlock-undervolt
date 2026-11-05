import sys, re
data = open(sys.argv[1], 'rb').read()
print(f"Tamanho: {len(data):,} bytes")
sigs = {
    b'_FVH': 'Volume de firmware UEFI (_FVH)',
    b'$_IFLASH': 'Capsula AMI AFU ($_IFLASH)',
    b'PK\x03\x04': 'ZIP',
    b"7z\xbc\xaf'\x1c": '7z',
    b'MSCF': 'CAB',
    b'\x5a\xa5\xf0\x0f': 'Flash descriptor Intel',
    b'Rar!\x1a\x07': 'RAR',
    b'Inno Setup': 'Inno Setup',
    b'Nullsoft': 'NSIS',
    b'AFUWIN': 'AFUWIN',
    b'$BIOSGUARD': 'BIOS Guard',
    b'\x8a\xa1\x98\x3d': '?',
}
for s, n in sigs.items():
    offs = [m.start() for m in re.finditer(re.escape(s), data)]
    if offs:
        print(f"{n:34} {len(offs):4}x  primeiros: {', '.join(hex(o) for o in offs[:6])}")
# UEFI capsule GUIDs (EFI_CAPSULE_HEADER, FMP capsule)
import uuid
for g, n in [('6dcbd5ed-e82d-4c44-bda1-7194199ad92a', 'FMP capsule'),
             ('3b6686bd-0d76-4030-b70e-b5519e2fc5a0', 'EFI capsule'),
             ('4a3ca68b-7723-48fb-803d-578cc1fec44d', 'AMI Aptio capsule'),
             ('14eeb5ae-8b98-4fac-a1ff-6ddc0b9bc6ee', 'AMI signed capsule')]:
    b = uuid.UUID(g).bytes_le
    offs = [m.start() for m in re.finditer(re.escape(b), data)]
    if offs:
        print(f"{n:34} {len(offs):4}x  primeiros: {', '.join(hex(o) for o in offs[:6])}")
names = sorted(set(m.group().decode() for m in re.finditer(rb'[A-Za-z0-9_\-]{3,40}\.(?:bin|cap|rom|fd|efi|exe|dll|sys|ini|txt|xml|zip)', data)))
print("Nomes embutidos:", ', '.join(names[:60]))
