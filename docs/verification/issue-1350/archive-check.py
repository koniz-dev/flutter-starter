from pathlib import Path
import sys,subprocess,json,tempfile,zipfile,tarfile,io,hashlib,os
from gh_rest_bridge import api
w=Path(__file__).resolve().parent;target=sys.argv[1];preflight='--preflight' in sys.argv[2:];version='v5.0.3'
assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==target
assert not subprocess.check_output(['git','status','--porcelain'],text=True).strip()
release=None
if not preflight:
 release=api('GET','releases/tags/'+version);assert not release['draft'] and not release['prerelease'] and release['published_at'];assert release['tag_name']==version
 assert release['body'].replace('\r\n','\n').strip()==(w/'1350-release-notes.md').read_text().strip()
 ref=api('GET','git/ref/tags/'+version)['object']
 while ref['type']=='tag':ref=api('GET','git/tags/'+ref['sha'])['object']
 assert ref['type']=='commit' and ref['sha']==target
 (w/'1350-release-metadata.json').write_text(json.dumps({'release':release,'resolved_tag':ref},indent=2)+'\n')
refname=target if preflight else version
archive=w/('1350-source-preflight.zip' if preflight else '1350-source.zip')
token=subprocess.check_output(['gh','auth','token'],text=True).strip();config='header = '+json.dumps('Authorization: Bearer '+token)+'\n'
r=subprocess.run(['curl','-q','--config','-','--silent','--show-error','--fail','--location','--connect-timeout','10','--max-time','120','--retry','2','--retry-delay','1','--output',str(archive),'https://api.github.com/repos/koniz-dev/flutter-starter/zipball/'+refname],input=config,text=True,capture_output=True);assert r.returncode==0,f'Archive download failed (curl exit {r.returncode})'
expected={};modes={}
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['git','archive','--format=tar',target]))) as tar:
 for item in tar:
  if item.isfile():expected[item.name]=tar.extractfile(item).read();modes[item.name]=bool(item.mode&0o111)
  elif item.issym():expected[item.name]=item.linkname.encode()
with zipfile.ZipFile(archive) as z:
 files=[i for i in z.infolist() if not i.is_dir()];prefix=files[0].filename.split('/',1)[0]+'/'
 actual={i.filename[len(prefix):]:i for i in files};assert set(actual)==set(expected)
 assert sum(i.file_size for i in files)==sum(len(v) for v in expected.values())
 for path,data in expected.items():
  assert z.read(actual[path])==data,path
  if path in modes:assert bool((actual[path].external_attr>>16)&0o111)==modes[path],path
 assert '**Starter version:** '+version in z.read(actual['docs/guides/migration/upgrading-this-starter.md']).decode()
 assert 'CLAUDE.local.md' not in actual and '.env' not in actual and not any(p.startswith('.git/') for p in actual)
manifest={'commit':target,'tree':subprocess.check_output(['git','rev-parse',target+'^{tree}'],text=True).strip(),'reference':refname,'release_url':release['html_url'] if release else None,'download_url':'https://api.github.com/repos/koniz-dev/flutter-starter/zipball/'+refname,'source_zip_url':'https://github.com/koniz-dev/flutter-starter/archive/refs/tags/'+version+'.zip' if release else None,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive_bytes':archive.stat().st_size,'source_files_verified':len(expected),'content_matches_git_archive':True,'executable_modes_verified':True,'starter_marker':version}
(w/('1350-source-archive-preflight.json' if preflight else '1350-source-archive-manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
