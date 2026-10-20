import json, os, subprocess, time
from pathlib import Path
from PIL import Image
import pymupdf

base=Path(__file__).resolve().parents[1]
(base/'qa').mkdir(exist_ok=True)
binary=base/'target/aarch64-unknown-linux-musl/release/pdfcraft-core'
qemu=Path(os.environ.get('PDFCRAFT_QEMU', 'qemu-aarch64-static'))
folder=base/'qa/native-session';folder.mkdir(exist_ok=True)
for p in folder.glob('*.json'): p.unlink()
demo=base/'port/pdfcraft-r36s/documents/Boas-vindas.pdf'
version=subprocess.check_output([str(qemu),'-cpu','cortex-a35',str(binary),'--version'],text=True)
assert 'aarch64' in version,version
print(version.strip(),flush=True)
pdf=pymupdf.open(demo)
protected=base/'qa/protected.pdf'
pdf.save(protected,encryption=pymupdf.PDF_ENCRYPT_AES_256,owner_pw='owner-test',user_pw='teste123')
pdf.close()
log=open(base/'qa/native.log','w')
process=subprocess.Popen([str(qemu),'-cpu','cortex-a35',str(binary),'serve',str(folder)],stdout=log,stderr=log,env={**os.environ,'RAYON_NUM_THREADS':'2'})
serial=0
def call(op,**values):
 global serial
 serial+=1
 request={'op':op,'id':serial,**values}
 (folder/'request.tmp').write_text(json.dumps(request))
 os.replace(folder/'request.tmp',folder/'request.json')
 until=time.monotonic()+60
 while time.monotonic()<until:
  p=folder/'response.json'
  if p.exists():
   reply=json.loads(p.read_text())
   if reply.get('id')==serial:
    print(op, 'ok='+str(reply.get('ok')), reply.get('error',''),flush=True)
    return reply
  if process.poll() is not None: raise RuntimeError('Core exited: '+str(process.returncode))
  time.sleep(.05)
 raise TimeoutError(op)
try:
 until=time.monotonic()+15
 while not (folder/'ready.json').exists():
  assert time.monotonic()<until
  time.sleep(.05)
 assert call('ping')['arch']=='aarch64'
 files=call('list',path=str(demo.parent));assert any(e['name']=='Boas-vindas.pdf' for e in files['entries'])
 assert call('open',path=str(demo))['count']==3
 r=call('render',page=0,scale=.8);assert r['ok']
 im=Image.open(r['file']);assert im.width>400 and im.height>600
 im.save(base/'qa/native-page1.png')
 r=call('text',page=1);assert r['ok'] and 'construção' in r['text'],r
 r=call('render',page=2,scale=.8);assert r['ok'] and r['width']>r['height']
 Image.open(r['file']).save(base/'qa/native-page3.png')
 r=call('render',page=0,scale=100);assert r['ok'] and r['limited']
 assert max(r['width'],r['height'])<=2048 and r['width']*r['height']<=2_010_000
 assert call('render',page=999,scale=1)['ok']==False
 r=call('open',path=str(protected));assert r['ok']==False and r['code']=='password'
 r=call('open',path=str(protected),password='wrong');assert r['ok']==False and r['code']=='password'
 assert call('open',path=str(protected),password='teste123')['ok']
 assert call('render',page=0,scale=.5)['ok']
 assert call('open',path=str(base/'qa/absent.pdf'))['ok']==False
 assert call('ping')['ok']
 assert call('close')['ok']
 assert call('render',page=0,scale=1)['ok']==False
 assert call('quit')['ok']
 process.wait(timeout=5)
 print('PASS: ARM64 Cortex-A35 emulation, file listing, 3-page PDF, PNG rendering, Portuguese text, landscape, zoom cap, encrypted PDF, bad password, invalid page/path, close.',flush=True)
finally:
 if process.poll() is None:process.terminate();process.wait(timeout=5)
 log.close()
