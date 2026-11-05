# Teste curto (so leitura) para comparar ligacoes do carregador no Windows, sem Kali.
# Uso:  python -I D:\BIOS_Otimizacao\testes\carregador\teste_carregador_tensao.py <nome_fase> [segundos_carga=120]
#   ex.: ...\teste_carregador_tensao.py A_como_esta      (carregador -> adaptador AV -> notebook)
#        ...\teste_carregador_tensao.py B_direto         (carregador direto na USB-C do notebook)
#        ...\teste_carregador_tensao.py C_bateria        (sem carregador, bateria > 50%)
#        ...\teste_carregador_tensao.py D_65W            (outro carregador PD >= 65 W, direto)
# Grava D:\BIOS_Otimizacao\testes\carregador\teste_<fase>.csv e imprime o resumo.
# Le apenas o HWiNFO (memoria compartilhada). Nao grava MSR, EC nem BIOS.
# Se a tensao da bateria cair (>~0,05 V) com o pacote em ~20 W, a bateria esta complementando o carregador.
import sys, time, csv, threading, statistics as st
sys.path.insert(0, r'D:\BIOS_Otimizacao\testes\scripts')
import hwsm, numpy as np

fase = sys.argv[1] if len(sys.argv) > 1 else 'fase'
dur = int(sys.argv[2]) if len(sys.argv) > 2 else 120
stop = threading.Event()

def burn():
    a = np.random.rand(2048, 2048)
    while not stop.is_set():
        a @ a

def rd():
    d = {}
    for s, l, u, v, *_ in hwsm.snap():
        if 'Enhanced' in s and l == 'Total System Power': d['sys'] = v
        if 'Enhanced' in s and l == 'CPU Package Power': d['pkg'] = v
        if 'Enhanced' in s and l == 'CPU Package': d['t'] = v
        if 'Performan' in s and l == 'IA: Package-Level RAPL/PBM PL2,PL3': d['rpl2'] = v
        if 'Performan' in s and l == 'IA: Max Turbo Limit': d['mtl'] = v
        if s.startswith('Battery') and l == 'Battery Voltage': d['v'] = v
        if s.startswith('Battery') and l == 'Remaining Capacity': d['cap'] = v
        if s.startswith('Battery') and l in ('Charge Rate', 'Discharge Rate'): d[l] = v
    return d

out = rf'D:\BIOS_Otimizacao\testes\carregador\teste_{fase}.csv'
rows = []
with open(out, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['t', 'etapa', 'sysW', 'pkgW', 'tPkg', 'rPL2', 'maxTurbo', 'battV', 'capWh', 'chgW', 'dischgW'])
    t0 = time.time(); th = None
    while True:
        el = time.time() - t0
        etapa = 'idle' if el < 15 else ('carga' if el < 15 + dur else 'resfr')
        if etapa == 'carga' and th is None:
            th = threading.Thread(target=burn, daemon=True); th.start()
        if etapa == 'resfr': stop.set()
        if el > 15 + dur + 30: break
        d = rd()
        r = [round(el, 1), etapa, d.get('sys'), d.get('pkg'), d.get('t'), d.get('rpl2'), d.get('mtl'),
             d.get('v'), d.get('cap'), d.get('Charge Rate'), d.get('Discharge Rate')]
        w.writerow(r); f.flush(); rows.append(r)
        if (d.get('t') or 0) >= 97:
            print('ABORT: temperatura >= 97 C'); stop.set()
        time.sleep(1)

idle = [r for r in rows if r[1] == 'idle' and r[7]]
car = [r for r in rows if r[1] == 'carga' and r[2] is not None][20:]
if idle and car:
    m = lambda i, rr: st.mean([x[i] for x in rr if x[i] is not None])
    print(f"{fase}: pacote {m(3, car):.1f} W | sistema {m(2, car):.1f} W | tPkg {m(4, car):.0f} C | "
          f"motivo PL2/PBM {100*m(5, car):.0f}% | V bat idle {m(7, idle):.3f} -> carga {m(7, car):.3f} "
          f"(min {min(x[7] for x in car):.3f}) | cap {car[0][8]} -> {car[-1][8]} Wh")
print('CSV:', out)
