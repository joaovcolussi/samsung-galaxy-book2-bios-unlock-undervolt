import mmap,struct
SM='Global\\HWiNFO_SENS_SM2'
import time,subprocess,os
def snap(tries=40):
    # tolerante: se o HWiNFO fechar/reiniciar, espera, reabre e tenta de novo (antes: WinError 87 derrubava o teste)
    for i in range(tries):
        try: return _snap()
        except (OSError,ValueError,IndexError,struct.error):
            if i==3 and not subprocess.run('tasklist /FI "IMAGENAME eq HWiNFO64.EXE" /NH',capture_output=True,text=True,shell=True).stdout.count('HWiNFO64'):
                os.startfile(r'C:\Program Files\HWiNFO64\HWiNFO64.EXE')
            time.sleep(3)
    return []
def _snap():
    m=mmap.mmap(-1,64,SM,access=mmap.ACCESS_READ)
    sig,ver,rev,pt,so,ss,sn,ro,rs,rn=struct.unpack_from('<IIIqIIIIII',m,0)
    tot=ro+rs*rn; m.close()
    if sig==0 or rn==0: raise ValueError('HWiNFO SM vazio')
    m=mmap.mmap(-1,tot,SM,access=mmap.ACCESS_READ); b=m[:]; m.close()
    cs=lambda x: x.split(b'\0')[0].decode('latin-1')
    sens=[cs(b[so+i*ss+8:so+i*ss+136]) for i in range(sn)]
    out=[]
    for i in range(rn):
        o=ro+i*rs
        t,si,rid=struct.unpack_from('<III',b,o)
        lab=cs(b[o+12:o+140]); unit=cs(b[o+268:o+284])
        v,vmin,vmax,vavg=struct.unpack_from('<dddd',b,o+284)
        out.append((sens[si],lab,unit,v,vmin,vmax,vavg))
    return out
if __name__=='__main__':
    for s,l,u,v,*_ in snap(): print(f"{s[:40]:40s} | {l[:45]:45s} | {v:10.2f} {u}")
