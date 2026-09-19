/* Measures hero element geometry + visibility at a given viewport. */
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path'), os = require('os'), http = require('http');

const target = process.argv[2];
const W = +process.argv[3];
const H = +process.argv[4];
const PORT = 9400 + Math.floor(Math.random() * 90);

const orig = fs.readFileSync(target, 'utf8');

const hook = [
'<script>',
'document.documentElement.className += " static";',
'setTimeout(function(){',
'  var ids = ["heroKick","heroTitle","heroSub","heroChips","heroCta"];',
'  var out = ids.map(function(i){',
'    var e = document.getElementById(i);',
'    if (!e) return { id:i, missing:true };',
'    var r = e.getBoundingClientRect();',
'    var cs = getComputedStyle(e);',
'    return { id:i, top:Math.round(r.top), bottom:Math.round(r.bottom), h:Math.round(r.height),',
'             opacity:cs.opacity, visibility:cs.visibility, display:cs.display,',
'             inViewport: r.bottom > 0 && r.top < innerHeight };',
'  });',
'  var rep = { vw:innerWidth, vh:innerHeight, els:out, bodyH:document.body.scrollHeight,',
'              heroH:(function(){var h=document.getElementById("inicio"); if(!h) return null;',
'                var r=h.getBoundingClientRect(); return {top:Math.round(r.top),h:Math.round(r.height)};})() };',
'  var x = new XMLHttpRequest();',
'  x.open("POST","/report",true);',
'  x.setRequestHeader("Content-Type","application/json");',
'  x.send(JSON.stringify(rep));',
'}, 1500);',
'<\/script>'
].join('\n');

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
const prof = path.join(os.tmpdir(), 'zia-hd-' + Date.now());
fs.mkdirSync(prof, { recursive: true });

let data = null;
const server = http.createServer((q, r) => {
  if (q.url === '/report' && q.method === 'POST') {
    let b = ''; q.on('data', c => b += c);
    q.on('end', () => { data = b; r.writeHead(200); r.end('ok'); });
    return;
  }
  r.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  r.end(injected);
});

server.listen(PORT, '127.0.0.1', () => {
  const env = Object.assign({}, process.env, {
    DBUS_SESSION_BUS_ADDRESS: 'disabled:', NO_AT_BRIDGE: '1',
    MOZ_HEADLESS: '1', MOZ_DISABLE_CONTENT_SANDBOX: '1',
  });
  const c = spawn('/usr/lib/firefox/firefox', [
    '--headless', '--no-remote', '--window-size', W + ',' + H,
    '--profile', prof, 'http://127.0.0.1:' + PORT + '/index.html',
  ], { env, stdio: ['ignore', 'ignore', 'ignore'] });
  setTimeout(() => {
    try { c.kill('SIGKILL'); } catch (e) {}
    server.close();
    console.log(data || 'NO_REPORT');
    process.exit(0);
  }, 14000);
});
