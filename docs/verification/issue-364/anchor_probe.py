import re,sys
md=open('docs/architecture/contracts-map.md').read().split('\n')
fix='--fix' in sys.argv
bad=0;fixed=0;total=0
alias={'register_screen.dart':'lib/features/auth/presentation/screens/register_screen.dart','task_detail_screen.dart':'lib/features/tasks/presentation/screens/task_detail_screen.dart'}
for li,line in enumerate(md):
    if not line.startswith('|') and '.dart:' not in line: continue
    cells=line.split('|') if line.startswith('|') else [line]
    newcells=[]
    for cell in cells:
        idents=set(re.findall(r'`([A-Za-z_][\w.]*(?:\(\))?)`',cell))
        idents={i.split('.')[-1].rstrip('()') for i in idents if not i.endswith('.dart') and '/' not in i}
        idents|={w for i in re.findall(r'`([^`]+)`',cell) for w in re.findall(r'[A-Za-z_]\w{3,}',i) if not i.endswith('.dart') and '/' not in i and ':' not in i}
        last=None
        def rep(m):
            global bad,fixed,total,last
            path,num=m.group(1),m.group(2)
            if path: last=alias.get(path,path)
            p=last
            if p is None: return m.group(0)
            total+=1
            try: src=open(p).read().split('\n')
            except Exception: print('MISSING',p); return m.group(0)
            n=int(num)
            ok=lambda k: 0<=k<len(src) and any(re.search(r'\b'+re.escape(i)+r'\b',src[k]) for i in idents)
            if ok(n-1): return m.group(0)
            bad+=1
            for d in (1,-1,2,-2,3,-3,4,-4,5,-5,6,-6):
                if ok(n-1+d):
                    print(f"md:{li+1} {p}:{n} -> {n+d}  [{src[n-1+d].strip()[:70]}]")
                    if fix:
                        fixed+=1; return f"`{m.group(1) or ''}:{n+d}`"
                    return m.group(0)
            print(f"md:{li+1} {p}:{n} UNRESOLVED [{src[n-1].strip()[:70] if n-1<len(src) else 'EOF'}] idents={sorted(idents)[:8]}")
            return m.group(0)
        cell=re.sub(r'`([A-Za-z0-9_/.]*\.dart)?:(\d+)`',rep,cell)
        newcells.append(cell)
    if fix: md[li]='|'.join(newcells) if line.startswith('|') else newcells[0]
print('total',total,'bad',bad,'fixed',fixed)
if fix: open('docs/architecture/contracts-map.md','w').write('\n'.join(md))
