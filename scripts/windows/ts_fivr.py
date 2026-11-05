# uso: python ts_fivr.py <ini> <mV negativo ou 0>  -> grava FIVR core(0)+cache(2) no perfil 0 do ThrottleStop.ini
import sys,re
ini,mv=sys.argv[1],int(sys.argv[2])
code=(round(mv*1.024)&0x7FF)<<21 if mv else 0
s=open(ini,encoding='latin-1').read()
for plane in (0,2):
    for key,val in ((f'UnlockVoltage{plane}0',str(1 if mv else 0)),(f'FIVRVoltage{plane}0',f'0x{code:08X}')):
        if re.search(rf'^{key}=.*$',s,re.M): s=re.sub(rf'^{key}=.*$',f'{key}={val}',s,flags=re.M)
        else: s=s.rstrip('\r\n')+f'\n{key}={val}\n'
open(ini,'w',encoding='latin-1').write(s)
print(f'{mv} mV -> 0x{code:08X}')
