import sys,time; sys.path.insert(0,sys.argv[1]); import hwsm
for i in range(int(sys.argv[2])):
    d={l:v for s,l,u,v,*_ in hwsm.snap() if 'Enhanced' in s and 'Power Limit' in l}
    print(time.strftime('%H:%M:%S'), {k.replace(' Power Limit',''):round(v,1) for k,v in d.items()}, flush=True); time.sleep(2)
