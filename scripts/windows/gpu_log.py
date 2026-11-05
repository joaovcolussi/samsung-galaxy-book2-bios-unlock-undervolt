# uso: python -I gpu_log.py <scripts_dir> <segundos_carga> <csv_saida> [iter]
# Abre gpu_stress.html no Edge (perfil temporario), le FPS pelo titulo da janela e sensores pelo HWiNFO; fecha no fim.
import sys, os, time, csv, subprocess, ctypes, tempfile, shutil
from ctypes import wintypes
SC, dur, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
it = sys.argv[4] if len(sys.argv) > 4 else '48'
sys.path.insert(0, SC)
import hwsm
KEYS = {'gpuW': ('Iris', 'IGPU Power'), 'gtW': ('Enhanced', 'GT Cores Power'), 'gvid': ('Iris', 'iGPU VID'),
        'gclk': ('Iris', 'GPU Clock'), 'guse': ('Iris', 'GPU Total Usage'), 'gtemp': ('Iris', 'GPU Core Temperature'),
        'pkgW': ('Enhanced', 'CPU Package Power'), 'tPkg': ('Enhanced', 'CPU Package'), 'sysW': ('Enhanced', 'Total System Power')}
def read():
    d = {}
    for s, l, u, v, *_ in hwsm.snap():
        for k, (ss, ll) in KEYS.items():
            if k not in d and ss in s and l == ll: d[k] = v
    return d
u32 = ctypes.windll.user32
def title():
    found = []
    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(h, _):
        n = u32.GetWindowTextLengthW(h)
        if n:
            b = ctypes.create_unicode_buffer(n + 1); u32.GetWindowTextW(h, b, n + 1)
            if b.value.startswith('GPU '): found.append(b.value)
        return True
    u32.EnumWindows(cb, 0)
    return found[0] if found else ''
edge = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
prof = os.path.join(os.environ['TEMP'], 'gpustress_%d' % os.getpid())
url = 'file:///' + os.path.join(SC, 'gpu_stress.html').replace('\\', '/') + '?it=' + it
p = subprocess.Popen([edge, '--user-data-dir=' + prof, '--no-first-run', '--app=' + url])
t0 = time.time(); rows = []
with open(out, 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['t', 'fps', 'titulo'] + list(KEYS))
    while time.time() - t0 < dur + 10:
        el = time.time() - t0; tt = title(); d = read()
        try: fps = float(tt.split()[1]) if tt.endswith('fps') else ''
        except Exception: fps = ''
        w.writerow([round(el), fps, tt] + [d.get(k, '') for k in KEYS]); f.flush()
        if el >= 10: rows.append((fps, d, tt))
        if int(el) % 15 == 0:
            print(f"{el:4.0f}s {tt:18s} iGPU {d.get('gpuW',0):5.1f}W GT {d.get('gtW',0):5.1f}W VID {d.get('gvid',0):.3f} {d.get('gclk',0):5.0f}MHz uso {d.get('guse',0):4.0f}% pkg {d.get('pkgW',0):5.1f}W {d.get('tPkg',0):3.0f}C", flush=True)
        time.sleep(max(0, 1 - (time.time() - t0 - el)))
subprocess.run(['taskkill', '/F', '/T', '/PID', str(p.pid)], capture_output=True)
# O launcher do Edge pode sair e deixar o browser vivo fora da arvore -> mata tudo que usa o perfil temporario.
tag = os.path.basename(prof)
ps = ("Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\" | ? { $_.CommandLine -like '*%s*' } | "
      "%% { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }") % tag
for _ in range(3):
    subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True); time.sleep(2)
left = subprocess.run(['powershell', '-NoProfile', '-Command',
      "@(Get-CimInstance Win32_Process -Filter \"Name='msedge.exe'\" | ? { $_.CommandLine -like '*%s*' }).Count" % tag],
      capture_output=True, text=True).stdout.strip()
print('Edge de teste restante:', left, flush=True)
shutil.rmtree(prof, ignore_errors=True)
ok = [r for r in rows if isinstance(r[0], float)]
def avg(k): v = [r[1].get(k, 0) for r in ok]; return sum(v) / max(1, len(v))
print('== RESUMO GPU')
print(f"amostras {len(ok)}/{len(rows)}  FPS medio {sum(r[0] for r in ok)/max(1,len(ok)):.2f}  iGPU {avg('gpuW'):.2f} W  GT {avg('gtW'):.2f} W  VID {avg('gvid'):.4f} V  clk {avg('gclk'):.0f} MHz  uso {avg('guse'):.0f}%  pkg {avg('pkgW'):.1f} W  {avg('tPkg'):.0f} C")
print('contexto perdido (TDR):', any('LOST' in r[2] for r in rows))
