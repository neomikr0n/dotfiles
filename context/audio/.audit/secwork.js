/* Section capture v4 — the reliable way.
   Firefox's --screenshot fires after load. To land on a section we transform the
   document itself: we delete every element BEFORE the target section, so the target
   is at the top of the document. That is fully deterministic at first paint. */
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');

const target = process.argv[2];
const label = process.argv[3] || 'sec';
const anchor = process.argv[4] || '';
const W = +(process.argv[5] || 1440);
const H = +(process.argv[6] || 950);
const PORT = 8900 + Math.floor(Math.random() * 90);

const orig = fs.readFileSync(target, 'utf8');

// Hide everything before the target using a runtime script that runs at parse time
// in <head> after DOMContentLoaded, then use scroll + a sticky marker.
const hook = `
<script>
(function(){
  function clamp(){
    var a = ${JSON.stringify(anchor)};
    if(!a) return;
    var el = document.getElementById(a.replace(/^#/,''));
    if(!el) return;
    // remove every previous sibling of the section's parent chain to bring it to top
    var node = el;
    while(node && node.parentNode && node.parentNode !== document.documentElement){
      var p = node.parentNode;
      var kids = Array.prototype.slice.call(p.children);
      var idx = kids.indexOf(node);
      for(var i=0;i<idx;i++){
        var k = kids[i];
        if(k.tagName==='SCRIPT') continue;
        if(k.id==='rail'||k.className && String(k.className).indexOf('grain')>=0) continue;
        k.style.display='none';
      }
      node = p;
    }
    window.scrollTo(0,0);
  }
  document.addEventListener('DOMContentLoaded', function(){
    try{ clamp(); }catch(e){}
    setTimeout(function(){ try{ clamp(); }catch(e){} window.scrollTo(0,0); }, 300);
    setTimeout(function(){ try{ clamp(); }catch(e){} window.scrollTo(0,0); }, 1200);
    setTimeout(function(){ try{ clamp(); }catch(e){} window.scrollTo(0,0); }, 2500);
  });
})();
</script>
`;

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
const prof = path.join(os.tmpdir(), 'zia-s4-'+label+'-'+Date.now());
fs.mkdirSync(prof, { recursive: true });

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(injected);
});

server.listen(PORT, '127.0.0.1', () => {
  const env = Object.assign({}, process.env, {
    DBUS_SESSION_BUS_ADDRESS: 'disabled:', NO_AT_BRIDGE: '1',
    MOZ_HEADLESS: '1', MOZ_DISABLE_CONTENT_SANDBOX: '1',
  });
  const shot = '/tmp/zialeaks/' + label + '.png';
  const child = spawn('/usr/lib/firefox/firefox', [
    '--headless','--no-remote','--window-size', W+','+H,
    '--profile', prof, '--screenshot', shot,
    'http://127.0.0.1:'+PORT+'/index.html',
  ], { env, stdio: ['ignore','ignore','ignore'] });
  const t = setTimeout(()=>{ try{child.kill('SIGKILL')}catch(e){} server.close(); console.log('shot:',shot); process.exit(0); }, 60000);
  child.on('exit', ()=>{ clearTimeout(t); server.close(); console.log('shot:',shot); process.exit(0); });
});
