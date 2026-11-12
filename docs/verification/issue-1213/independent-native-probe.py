from pathlib import Path
import subprocess,json,plistlib,xml.etree.ElementTree as ET,re
w=Path('.git/codex-issue-work');log=w/'1213-sdk350-review.log';base='e14ad8f14073304f349fe45b9823b810c47c1983';head='f8c24aaac382198520ae1180aa61c2b03ffdb191'
def record(s):
 with log.open('a') as f:f.write(s+'\n')
def run(args):
 p=subprocess.run(args,text=True,capture_output=True);record('$ '+repr(args)+'\n'+p.stdout+p.stderr+'\nexit:'+str(p.returncode));assert p.returncode==0;return p.stdout
def blob(ref,p):return subprocess.check_output(['git','show',ref+':'+p])
def pbx(ref,platform):
 raw=blob(ref,f'{platform}/Runner.xcodeproj/project.pbxproj');p=w/f'1213-review-{platform}-{ref[:8]}.pbxproj';p.write_bytes(raw);return json.loads(run(['plutil','-convert','json','-o','-',str(p)]))
count=0
for platform in ['ios','macos']:
 a=pbx(base,platform);b=pbx(head,platform);o=b['objects']
 for uid,obj in a['objects'].items():
  if obj['isa']=='XCBuildConfiguration':
   assert obj['name']==o[uid]['name'];assert obj['buildSettings']==o[uid]['buildSettings'],(platform,uid,obj['name']);count+=1;record(f'UNCHANGED {platform} configuration {uid} {obj["name"]}: '+json.dumps(obj['buildSettings'],sort_keys=True))
 def refs(v):
  if isinstance(v,dict):
   for value in v.values():yield from refs(value)
  elif isinstance(v,list):
   for value in v:yield from refs(value)
  elif isinstance(v,str) and re.fullmatch('[0-9A-F]{24}',v):yield v
 missing=set(refs(b))-set(o);assert not missing,missing
 project=o[b['rootObject']]; packages=[o[uid] for uid in project['packageReferences']];assert len(packages)==1;assert packages[0]['relativePath']=='Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage'
 runners=[(uid,obj) for uid,obj in o.items() if obj['isa']=='PBXNativeTarget' and obj['name']=='Runner'];assert len(runners)==1;runnerid,runner=runners[0]
 products=[o[uid] for uid in runner['packageProductDependencies']];assert products==[{'isa':'XCSwiftPackageProductDependency','productName':'FlutterGeneratedPluginSwiftPackage'}]
 # The linked product must be in Runner's actual Frameworks phase.
 frameworks=[o[x] for x in runner['buildPhases'] if o[x]['isa']=='PBXFrameworksBuildPhase'];assert len(frameworks)==1
 assert any(o[x].get('productRef') in runner['packageProductDependencies'] for x in frameworks[0]['files'])
 assert any(o[x].get('name')=='[CP] Check Pods Manifest.lock' for x in runner['buildPhases'])
 scheme=f'{platform}/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme';sa=ET.fromstring(blob(base,scheme));sb=ET.fromstring(blob(head,scheme));pre=sb.find('BuildAction/PreActions');assert pre is not None
 acts=pre.findall('ExecutionAction');assert len(acts)==1;content=acts[0].find('ActionContent');script=content.attrib['scriptText'];assert ('"$FLUTTER_ROOT/' in script or '"$FLUTTER_ROOT"/' in script) and script.rstrip().endswith('prepare');ref=content.find('EnvironmentBuildable/BuildableReference');assert ref.attrib['BlueprintIdentifier']==runnerid
 sb.find('BuildAction').remove(pre);assert ET.tostring(sa)==ET.tostring(sb),'Scheme changed beyond prepare action'
 ws=f'{platform}/Runner.xcworkspace/contents.xcworkspacedata';wa=ET.fromstring(blob(base,ws));wb=ET.fromstring(blob(head,ws));assert [x.attrib for x in wa]==[{'location':'group:Runner.xcodeproj'}];assert [x.attrib for x in wb]==[{'location':'group:Runner.xcodeproj'},{'location':'group:Pods/Pods.xcodeproj'}]
 pin=json.loads(blob(head,f'{platform}/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'));assert pin['pins']==[{'identity':'cocoaasyncsocket','kind':'remoteSourceControl','location':'https://github.com/robbiehanson/CocoaAsyncSocket','state':{'revision':'dbdc00669c1ced63b27c3c5f052ee4d28f10150c','version':'7.6.5'}}]
 record(f'PASS {platform}: object references all resolve; Runner links generated Swift package; prepare action correct target/quoting and otherwise unchanged scheme; workspace retains Runner and adds Pods; expected CocoaAsyncSocket pin.')
assert count==21,count
pa=plistlib.loads(blob(base,'ios/Runner/Info.plist'));pb=plistlib.loads(blob(head,'ios/Runner/Info.plist'));manifest=pb.pop('UIApplicationSceneManifest');assert pa==pb
assert manifest=={'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneClassName':'UIWindowScene','UISceneConfigurationName':'flutter','UISceneDelegateClassName':'FlutterSceneDelegate','UISceneStoryboardFile':'Main'}]}}
a=plistlib.loads(blob(base,'ios/Flutter/AppFrameworkInfo.plist'));b=plistlib.loads(blob(head,'ios/Flutter/AppFrameworkInfo.plist'));assert a.pop('MinimumOSVersion')=='13.0';assert a==b
app=blob(head,'ios/Runner/AppDelegate.swift').decode();template=Path('.git/codex-issue-work/sdk-350/flutter/packages/flutter_tools/templates/app/ios.tmpl/Runner/AppDelegate.swift').read_text();assert app.strip()==template.strip();assert app.count('GeneratedPluginRegistrant.register(')==1
story=ET.fromstring(blob(head,'ios/Runner/Base.lproj/Main.storyboard'));assert any(x.attrib.get('customClass')=='FlutterViewController' for x in story.iter())
record('PASS iOS plist preserves every pre-existing key/value and adds only expected single-scene manifest; AppFramework stale13.0 minimum removed, target settings remain identical. Main storyboard remains FlutterViewController. AppDelegate exactly matches current SDK template, with one registrant call at implicit-engine initialization.')
up=run(['git','ls-remote','https://github.com/robbiehanson/CocoaAsyncSocket.git','refs/tags/7.6.5']);assert up.split()[0]=='dbdc00669c1ced63b27c3c5f052ee4d28f10150c'
record('PASS upstream CocoaAsyncSocket7.6.5 tag matches both committed pins. No new native package version: old CocoaPods lock had7.6.5; Patrol4.11 SwiftPM manifest names same upstream dependency from7.6.4.')
record('PRIMARY SDK sources: packages/flutter_tools/templates/app/ios.tmpl/Runner/AppDelegate.swift and lib/src/migrations/uiscene_migration.dart; official guides https://docs.flutter.dev/release/breaking-changes/uiscenedelegate and https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers. UIScene callback migration and optional CocoaPods fallback match documented supported mechanisms.')
print('Independent structural and pin probes passed; 21 build configurations unchanged.')
