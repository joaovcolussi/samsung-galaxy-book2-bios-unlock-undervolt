# uso: python stress_log.py <segundos_carga> <segundos_resfriar> <csv_saida>
import sys,time,threading,csv,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import hwsm, numpy as np
dur,cool,out=int(sys.argv[1]),int(sys.argv[2]),sys.argv[3]
KEYS={'pkgW':('Enhanced','CPU Package Power'),'tPkg':('Enhanced','CPU Package'),'tMax':('DTS','Core Max'),
 'pl1s':('Enhanced','PL1 Power Limit (Static)'),'pl1d':('Enhanced','PL1 Power Limit (Dynamic)'),
 'pl2s':('Enhanced','PL2 Power Limit (Static)'),'pl2d':('Enhanced','PL2 Power Limit (Dynamic)'),
 'clk':('i7-1255U','Average Effective Clock'),'p0':('i7-1255U','P-core 0 Clock'),'e2':('i7-1255U','E-core 2 Clock'),
 'thr':('DTS','Package/Ring Thermal Throttling'),'rPL1':('Performan','IA: Package-Level RAPL/PBM PL1'),
 'rPL2':('Performan','IA: Package-Level RAPL/PBM PL2,PL3'),'rTh':('Performan','IA: Running Average Thermal Limit'),
 'vid':('i7-1255U','P-core 0 VID'),'sysW':('Enhanced','Total System Power')}
def read():
    d={}
    for s,l,u,v,*_ in hwsm.snap():
        for k,(ss,ll) in KEYS.items():
            if k not in d and ss in s and l==ll: d[k]=v
    return d
stop=threading.Event(); work=[0]
def burn():
    a=np.random.rand(2048,2048).astype(np.float64)
    while not stop.is_set(): a@a; work[0]+=1
t0=time.time(); rows=[]; th=None
with open(out,'w',newline='') as f:
    w=csv.writer(f); w.writerow(['t','fase','gflop_s']+list(KEYS))
    last=0; lw=0
    while True:
        el=time.time()-t0
        if th is None and el>=10: th=threading.Thread(target=burn,daemon=True); th.start()
        if el>=10+dur and not stop.is_set(): stop.set()
        if el>=10+dur+cool: break
        fase='idle' if el<10 else ('carga' if el<10+dur else 'resfr')
        d=read(); g=(work[0]-lw)*2*2048**3/1e9; lw=work[0]
        w.writerow([round(el)]+[fase,round(g,1)]+[d.get(k,'') for k in KEYS]); f.flush()
        rows.append((el,fase,g,d))
        if d.get('tMax',0)>=99: print('ABORT: temp >=99C'); stop.set()
        if int(el)%15==0:
            print(f"{el:5.0f}s {fase:5s} {d.get('pkgW',0):5.1f}W {d.get('tPkg',0):3.0f}C max{d.get('tMax',0):3.0f}C clk{d.get('clk',0):5.0f} P0 {d.get('p0',0):4.0f} E {d.get('e2',0):4.0f} PL1 s{d.get('pl1s',0):.0f}/d{d.get('pl1d',0):.0f} PL2 s{d.get('pl2s',0):.0f}/d{d.get('pl2d',0):.0f} thr{d.get('thr',0):.0f} rPL1 {d.get('rPL1',0):.0f} rPL2 {d.get('rPL2',0):.0f} {g:6.1f}GF",flush=True)
        time.sleep(max(0,1-(time.time()-t0-el)))
c=[r for r in rows if r[1]=='carga']
def avg(k,rs): v=[r[3].get(k,0) for r in rs]; return sum(v)/max(1,len(v))
first=[r for r in c if r[0]<10+30]; last=[r for r in c if r[0]>10+dur-90]
print("== RESUMO")
print(f"30s iniciais: {avg('pkgW',first):.1f} W, {avg('tPkg',first):.0f} C, clk {avg('clk',first):.0f} MHz")
print(f"90s finais  : {avg('pkgW',last):.1f} W, {avg('tPkg',last):.0f} C (max {max(r[3].get('tMax',0) for r in c):.0f}), clk {avg('clk',last):.0f} MHz, GFLOPS {sum(r[2] for r in last)/max(1,len(last)):.1f}")
print(f"PL1 dinamico min/max na carga: {min(r[3].get('pl1d',0) for r in c):.0f}/{max(r[3].get('pl1d',0) for r in c):.0f}")
