/* Diagnostic runner v2 — serves the instrumented HTML over HTTP on 127.0.0.1
   so XHR reporting is same-origin-friendly, then collects diagnostics. */
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');

const target = process.argv[2];
const label = process.argv[3] || 'run';
const W = +(process.argv[4] || 1440);
const H = +(process.argv[5] || 900);
const REPORT_PORT = 8791;

const orig = fs.readFileSync(target, 'utf8');

const hook = `
<script>
(function(){
  window.__diag = {errors:[], console_errors:[], warnings:[]};
  window.addEventListener('error', function(e){
    window.__diag.errors.push((e.message||'error') + ' @line' + (e.lineno||'?') + ':' + (e.colno||'?'));
  }, true);
  window.addEventListener('unhandledrejection', function(e){
    window.__diag.errors.push('UNHANDLED_REJECTION: ' + ((e.reason&&e.reason.message)||e.reason));
  });
  var _ce = console.error, _cw = console.warn;
  console.error = function(){ window.__diag.console_errors.push([].join.call(arguments,' ')); _ce.apply(console, arguments); };
  console.warn  = function(){ window.__diag.warnings.push([].join.call(arguments,' ')); _cw.apply(console, arguments); };

  function collect(){
    var canv = [];
    document.querySelectorAll('canvas').forEach(function(c){
      var blank = null, err=null;
      try {
        var g = c.getContext('2d');
        if (g && c.width && c.height) {
          var d = g.getImageData(0,0,Math.min(c.width,400),Math.min(c.height,400)).data;
          var nz = 0;
          for (var i=3;i<d.length;i+=4) if (d[i]!==0) nz++;
          blank = (nz===0);
        }
      } catch(e2){ err = e2.message; }
      canv.push({id:c.id||'(none)', cw:c.clientWidth, ch:c.clientHeight, aw:c.width, ah:c.height, sh:c.style.height||null, blank:blank, err:err});
    });
    var svgs = [];
    document.querySelectorAll('svg[id]').forEach(function(s){
      var b=null; try{ var bb=s.getBBox(); b={w:Math.round(bb.width),h:Math.round(bb.height)}; }catch(e){ b='ERR'; }
      svgs.push({id:s.id, bbox:b, cls:s.getAttribute('class')||''});
    });
    var broken=[];
    document.querySelectorAll('img').forEach(function(im){ if(im.complete && im.naturalWidth===0) broken.push(im.id||im.className||'(img)'); });
    var hidden=[];
    document.querySelectorAll('.reveal').forEach(function(el){
      if(!el.classList.contains('in')) hidden.push((el.id||el.className||'?').slice(0,60));
    });
    // styling / var sanity
    var cs = getComputedStyle(document.documentElement);
    var probe = {
      railDisplay: getComputedStyle(document.getElementById('rail')||document.body).display,
      bodyBg: getComputedStyle(document.body).backgroundColor,
      progTransform: (document.getElementById('progress')||{}).style ? document.getElementById('progress').style.transform : null,
    };
    return {
      errors: window.__diag.errors,
      console_errors: window.__diag.console_errors,
      warnings: window.__diag.warnings.slice(0,25),
      ziaErrors: window.__ziaErrors||null,
      animsSize: (window.__zia && window.__zia.animsSize)||null,
      frames: (window.__zia && window.__zia.frames)||null,
      revealIO: (window.__zia && window.__zia.revealIO)||null,
      canvases: canv, svgs: svgs, brokenImgs: broken, notRevealed: hidden.slice(0,25),
      docH: document.body.scrollHeight, docW: document.body.scrollWidth, probe: probe
    };
  }
  window.__collect = collect;

  function report(){
    try{
      var data = JSON.stringify(collect());
      var x = new XMLHttpRequest();
      x.open('POST','/report', true);
      x.setRequestHeader('Content-Type','application/json');
      x.send(data);
    }catch(e){}
  }
  function run(){
    var y=0, step=Math.max(400, Math.floor(window.innerHeight*0.7));
    var iv = setInterval(function(){
      y += step;
      window.scrollTo(0, y);
      if (y > document.body.scrollHeight + window.innerHeight) {
        clearInterval(iv);
        window.scrollTo(0,0);
        setTimeout(report, 2500);
      }
    }, 120);
  }
  setTimeout(run, 1200);
})();
</script>
`;

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
if (injected === orig) { console.error('NO_HEAD'); process.exit(2); }

let reportData = null;
const server = http.createServer((req, res) => {
  if (req.url === '/report' && req.method === 'POST') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => { reportData = body; res.writeHead(200); res.end('ok'); });
    return;
  }
  if (req.url === '/' || req.url.startsWith('/index')) {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(injected);
    return;
  }
  res.writeHead(404); res.end('nf');
});

const prof = path.join(os.tmpdir(), 'zia-prof-' + label + '-' + Date.now());
fs.mkdirSync(prof, { recursive: true });

server.listen(REPORT_PORT, '127.0.0.1', () => {
  const env = Object.assign({}, process.env, {
    DBUS_SESSION_BUS_ADDRESS: 'disabled:',
    NO_AT_BRIDGE: '1',
    MOZ_HEADLESS: '1',
    MOZ_DISABLE_CONTENT_SANDBOX: '1',
  });
  const child = spawn('/usr/lib/firefox/firefox', [
    '--headless', '--no-remote',
    '--window-size', W + ',' + H,
    '--profile', prof,
    'http://127.0.0.1:' + REPORT_PORT + '/index.html',
  ], { env, stdio: ['ignore', 'ignore', 'ignore'] });

  const killT = setTimeout(() => { try { child.kill('SIGKILL'); } catch (e) {} }, 70000);

  setTimeout(() => {
    clearTimeout(killT);
    try { child.kill('SIGKILL'); } catch (e) {}
    server.close();
    if (reportData) {
      console.log('===REPORT_START===');
      try { console.log(JSON.stringify(JSON.parse(reportData), null, 1)); }
      catch (e) { console.log(reportData); }
      console.log('===REPORT_END===');
    } else {
      console.log('===NO_REPORT_RECEIVED===');
    }
    process.exit(0);
  }, 34000);
});
