import sys, os
base = sys.argv[1]
def rd(p): return open(os.path.join(base,p),'rb').read()
pairs = {
 'CpuSetup': ('14 CpuSetup/body.bin','0 StdDefaults/4 CpuSetup/body.bin'),
 'Setup':    ('99 Setup/body.bin','0 StdDefaults/0 Setup/body.bin'),
 'SaSetup':  ('11 SaSetup/body.bin','0 StdDefaults/5 SaSetup/body.bin'),
 'PchSetup': ('12 PchSetup/body.bin','0 StdDefaults/6 PchSetup/body.bin'),
}
cur={}
for n,(a,b) in pairs.items():
    A,B = rd(a),rd(b); cur[n]=A
    d=[i for i in range(min(len(A),len(B))) if A[i]!=B[i]]
    print(f"== {n}: atual {len(A):#x} / padrao {len(B):#x}, {len(d)} bytes diferentes")
    for i in d: print(f"   {i:#06x}: padrao {B[i]:#04x} -> atual {A[i]:#04x}")
C=cur['CpuSetup']; S=cur['Setup']
def v(buf,o,n): return int.from_bytes(buf[o:o+n],'little')
m=[('PL1',0x17,4),('PL1 Override',0x1b,1),('Tau',0x1c,1),('PL2 Override',0x1d,1),('PL2',0x1e,4),
('cTDP Nom PL1',0x5b,4),('cTDP Nom PL2',0x5f,4),('cTDP Nom Tau',0x63,1),('cTDP L1 PL1',0x65,4),('cTDP L1 PL2',0x69,4),
('cTDP L2 PL1',0x6f,4),('cTDP L2 PL2',0x73,4),('Enable cTDP',0x227,1),('cTDP Boot Mode',0x44,1),('PkgPL MSR Lock',0x30,1),
('PL4 Override',0x2a,1),('PL4',0x2b,4),('OC Lock',0x10e,1),('OC Feature',0x1d9,1),('CFG Lock',0x43,1),
('Pcore Vofs',0x1e0,2),('Pcore prefix',0x1e2,1),('E0 Vofs',0x315,2),('E1 Vofs',0x317,2),('E2',0x319,2),('E3',0x31b,2),
('Eprefix0',0x31d,1),('Eprefix1',0x31e,1),('Eprefix2',0x31f,1),('Eprefix3',0x320,1),
('TCC Offset',0x7f,1),('Boot perf',0x13,1),('Turbo',0x16,1),('TVB',0x2e3,1)]
print("== Valores atuais (CpuSetup)")
for n,o,s in m: print(f"   {n:16s} @{o:#05x} = {v(C,o,s)}")
print(f"   DTT (Setup @0x6d2) = {S[0x6d2]}")
