# imprime a carga de fundo atual (GPU deve estar ~0% antes de um teste)
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import hwsm
for s, l, u, v, *_ in hwsm.snap():
    if l in ('GPU Total Usage', 'IGPU Power', 'CPU Package Power', 'Total CPU Usage', 'CPU Package'): print(' ', l, round(v, 1), u)
