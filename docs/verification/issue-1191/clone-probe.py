import pathlib,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[2]
ref=sys.argv[1]; name=sys.argv[2]
clone=root/'.git/codex-issue-work'/('1191-clone-'+name)
def run(args,cwd=None):
 print('$ '+' '.join(map(str,args)),flush=True)
 r=subprocess.run(list(map(str,args)),cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 print(r.stdout,end='',flush=True);print('exit:',r.returncode,flush=True)
 return r
assert not clone.exists(),clone
assert run(['git','-c','core.autocrlf=true','clone','--local','--shared','--no-checkout',root,clone]).returncode==0
assert run(['git','config','core.autocrlf','true'],clone).returncode==0
assert run(['git','checkout','--detach',ref],clone).returncode==0
run(['git','config','--get','core.autocrlf'],clone)
run(['git','check-attr','eol','--','.githooks/commit-msg','scripts/dev/create_feature.sh'],clone)
hook=clone/'.githooks/commit-msg';data=hook.read_bytes()
print('commit-msg CRLF count:',data.count(bytes([13,10])),flush=True)
msg=root/'.git/codex-issue-work/1191-valid-message.txt';msg.write_text('fix(tooling): verify shell checkout\n')
r=run(['bash',hook,msg],clone)
print('RESULT:',name,'hook exit',r.returncode,flush=True)
if name=='fixed':
 assert bytes([13,10]) not in data
 assert r.returncode==0
else: assert r.returncode!=0
