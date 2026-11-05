import re,sys
t=open(sys.argv[1],encoding='utf-8',errors='replace').read().splitlines()
vs={}
for l in t:
    m=re.search(r'VarStore(?:Efi)? Guid: [0-9A-F-]+, VarStoreId: (0x[0-9A-F]+),.*Name: "([^"]+)"',l)
    if m: vs[m.group(1)]=m.group(2)
want=[("CpuSetup",o) for o in (0x17,0x1b,0x1c,0x1d,0x1e,0x5b,0x5f,0x63,0x65,0x69,0x6f,0x73,0x227,0x44,0x30,0x2a,0x2b,0x2f,0x10e,0x1d9,0x43,0x1e0,0x1e2,0x315,0x317,0x319,0x31b,0x31d,0x31e,0x31f,0x320,0x7f,0x13,0x16,0x2e3,0x1dd,0x1e5)]+[("Setup",0x6d2)]
found={}
for l in t:
    m=re.search(r'(OneOf|Numeric|CheckBox) Prompt: "([^"]*)".*?VarStoreId: (0x[0-9A-F]+), VarOffset: (0x[0-9A-F]+)',l)
    if m:
        k=(vs.get(m.group(3),m.group(3)),int(m.group(4),16))
        found.setdefault(k,[]).append(m.group(2))
for k in want: print(f"{k[0]:9s} {k[1]:#06x}  {found.get(k,'*** NAO ENCONTRADO ***')}")
