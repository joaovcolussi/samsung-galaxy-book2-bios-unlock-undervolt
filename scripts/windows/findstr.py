import os,sys
pat="Overclocking Lock".encode('utf-16-le')
for r,d,f in os.walk(sys.argv[1]):
    for n in f:
        if n=='body.bin':
            p=os.path.join(r,n)
            if os.path.getsize(p)>50_000_000: continue
            if pat in open(p,'rb').read(): print(os.path.getsize(p), p)
