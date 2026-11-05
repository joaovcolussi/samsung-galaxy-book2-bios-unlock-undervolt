import sys, re, json
src = sys.argv[1]
kw = re.compile(sys.argv[2], re.I) if len(sys.argv) > 2 else None
lines = open(src, encoding='utf-8', errors='replace').read().splitlines()
stores = {}
for l in lines:
    m = re.search(r'VarStore Guid: ([0-9A-F\-]+), VarStoreId: (0x[0-9A-F]+), Size: (0x[0-9A-F]+), Name: "([^"]+)"', l)
    if m: stores[int(m.group(2), 16)] = m.group(4)
items = []; cur = None; form = ''
for l in lines:
    s = l.strip()
    fm = re.match(r'Form FormId: 0x[0-9A-F]+, Title: "([^"]*)"', s)
    if fm: form = fm.group(1)
    m = re.match(r'(OneOf|Numeric|CheckBox) Prompt: "([^"]*)", Help: "([^"]*)".*?VarStoreId: (0x[0-9A-F]+), VarOffset: (0x[0-9A-F]+)(?:.*?Size: (\d+))?(?:, Min: (0x[0-9A-F]+), Max: (0x[0-9A-F]+))?', s)
    if m:
        cur = dict(kind=m.group(1), prompt=m.group(2), help=m.group(3), store=stores.get(int(m.group(4), 16), m.group(4)),
                   off=int(m.group(5), 16), size=int(m.group(6) or 8) // 8, min=m.group(7), max=m.group(8), opts=[], default=None, form=form)
        items.append(cur); continue
    if cur is not None:
        o = re.match(r'OneOfOption Option: "([^"]*)" Value: (\d+)(.*)', s)
        if o:
            cur['opts'].append(f"{o.group(2)}={o.group(1)}")
            if 'Default' in o.group(3) and cur['default'] is None: cur['default'] = o.group(2)
            continue
        dm = re.match(r'Default DefaultId: 0x0 Value: (\d+)', s)
        if dm and cur['default'] is None: cur['default'] = dm.group(1); continue
        if s.startswith('End') and cur['kind'] != 'OneOf': cur = None
        if s.startswith('End') and cur and cur['kind'] == 'OneOf' and cur['opts']: cur = None
seen = set()
for it in items:
    text = it['prompt'] + ' ' + it['help']
    if kw and not kw.search(text): continue
    key = (it['store'], it['off'], it['prompt'])
    if key in seen: continue
    seen.add(key)
    rng = f"[{int(it['min'],16)}..{int(it['max'],16)}]" if it['min'] else ''
    opts = ' | '.join(it['opts'][:8]) + (' ...' if len(it['opts']) > 8 else '')
    print(f"{it['store']:9} 0x{it['off']:03X} {it['size']}B  def={it['default']!s:6} {it['prompt'][:46]:46} {rng:16} {opts[:90]}")
    print(f"{'':16}<{it['form'][:40]}> {it['help'][:150]}")
