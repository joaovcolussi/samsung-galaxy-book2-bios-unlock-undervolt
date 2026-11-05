"""Compara pos-metal (38/39/40) com referencias pre-metal (33/34/37). Uso: python -I comparar_pos_metal.py"""
import csv, statistics as st, os
T = r"D:\BIOS_Otimizacao\testes"
PARES = [
    ("CPU single (Desempenho)", "33_etapa3b_desempenho_single.csv", "38_pos_metal_desempenho_single.csv", "cpu"),
    ("CPU multi (Equilibrado)", "34_etapa3b_equilibrado_multi.csv", "39_pos_metal_equilibrado_multi.csv", "cpu"),
    ("CPU single LIMPO (Desempenho)", "33_etapa3b_desempenho_single.csv", "41_pos_metal2_desempenho_single.csv", "cpu"),
    ("CPU multi LIMPO (Equilibrado)", "34_etapa3b_equilibrado_multi.csv", "42_pos_metal2_equilibrado_multi.csv", "cpu"),
    ("GPU LIMPO", "37_etapa3c_gpu.csv", "43_pos_metal2_gpu.csv", "gpu"),
    ("GPU WebGL (GT LL 1,85)", "37_etapa3c_gpu.csv", "40_pos_metal_gpu.csv", "gpu"),
]
CPU = ["gflop_s", "pkgW", "tPkg", "tMax", "p0", "e2", "vid", "thr", "rPL2", "rTh"]
GPU = ["fps", "gclk", "gvid", "pkgW", "tPkg", "guse"]

def load(fn, kind):
    p = os.path.join(T, fn)
    if not os.path.exists(p):
        return None
    rows = list(csv.DictReader(open(p, newline="")))
    if kind == "cpu":
        rows = [r for r in rows if r.get("fase") == "carga"]
        rows = rows[30:] if len(rows) > 60 else rows   # descarta 30 s iniciais
    else:
        rows = [r for r in rows if r.get("fps")]
        rows = rows[30:] if len(rows) > 60 else rows
    return rows

def m(rows, k):
    v = []
    for r in rows:
        try: v.append(float(r[k]))
        except (ValueError, KeyError, TypeError): pass
    return st.mean(v) if v else float("nan")

def salto(fn):
    """Subida de tPkg nos primeiros 3 s de carga vs ultimo idle (qualidade da interface)."""
    p = os.path.join(T, fn)
    if not os.path.exists(p): return None
    rows = list(csv.DictReader(open(p, newline="")))
    idle = [r for r in rows if r.get("fase") == "idle"]
    carga = [r for r in rows if r.get("fase") == "carga"]
    if not idle or len(carga) < 4: return None
    return float(carga[3]["tPkg"]) - float(idle[-1]["tPkg"])

for nome, a, b, kind in PARES:
    ra, rb = load(a, kind), load(b, kind)
    print(f"\n== {nome}: {a}  vs  {b}")
    if ra is None or rb is None:
        print("   (arquivo ausente)"); continue
    for k in (CPU if kind == "cpu" else GPU):
        va, vb = m(ra, k), m(rb, k)
        print(f"   {k:8s} antes {va:9.3f}   depois {vb:9.3f}   delta {vb - va:+9.3f}")
    if kind == "cpu":
        print(f"   salto termico 3 s: antes {salto(a)}  depois {salto(b)}")
