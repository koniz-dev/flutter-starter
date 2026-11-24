from pathlib import Path
import sys,subprocess,json,hashlib,shutil
root=Path.cwd();w=Path(__file__).resolve().parent;target=sys.argv[1]
def git(*a):return subprocess.check_output(['git',*a],text=True).strip()
assert git('rev-parse','HEAD')==target and git('branch','--show-current')=='main' and not git('status','--porcelain')
command=['flutter','build','web','--release','--dart-define=ENVIRONMENT=staging','--dart-define=BASE_URL=https://api.delivery-check.invalid','--dart-define=ENABLE_SSL_PINNING=false']
with (w/'1350-web-build.log').open('w') as log:
 log.write('Source main: '+target+'\n$ '+' '.join(command)+'\n');log.flush();r=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT);log.write(f'\nexit: {r.returncode}\n')
assert r.returncode==0
out=root/'build/web';assert (out/'index.html').is_file();compiled=[p for p in [out/'main.dart.js',out/'main.dart.wasm'] if p.is_file()];assert compiled
assert not git('status','--porcelain'),'Build modified tracked/untracked source'
artifacts=[]
for p in [out/'index.html',out/'flutter_bootstrap.js',*compiled]:
 if p.exists():assert p.stat().st_size>0;artifacts.append(dict(path=str(p.relative_to(root)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
files=[p for p in out.rglob('*') if p.is_file()]
sdk=json.loads(subprocess.check_output(['flutter','--version','--machine'],text=True))
manifest={'flutter_executable':shutil.which('flutter'),'sdk':sdk,'commit':target,'tree':git('rev-parse','HEAD^{tree}'),'command':command,'exit':0,'artifacts':artifacts,'total_files':len(files),'total_bytes':sum(p.stat().st_size for p in files),'backend':'throwaway HTTPS .invalid URL; compilation only, no live-backend/store-signing assurance','source_clean_after_build':True}
(w/'1350-web-build-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
