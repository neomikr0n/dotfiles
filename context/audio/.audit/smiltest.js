/* SMIL motion test: sample animateMotion-driven circle positions over time to prove
   the packet dots actually MOVE (not frozen) in Gecko. Also verifies the CSS keyframe
   animations are attached and running. */
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path'), os = require('os'), http = require('http');

const target = process.argv[2];
const W = +(process.argv[3] || 1440);
const H = +(process.argv[4] || 900);
const PORT = 9500 + Math.floor(Math.random() * 90);

const orig = fs.readFileSync(target, 'utf8');

const hook = [
'<script>',
'(function(){',
'  var errs=[];',
'  window.addEventListener("error",function(e){errs.push((e.message||"e")+" @"+e.lineno);},true);',
'  function snap(){',
'    var out=[];',
'    document.querySelectorAll("circle").forEach(function(c,i){',
'      var m=c.querySelector("animateMotion");',
'      if(!m) return;',
'      var b=c.getBoundingClientRect();',
'      out.push({i:i, x:+(b.left+b.width/2).toFixed(2), y:+(b.top+b.height/2).toFixed(2),',
'                dur:m.getAttribute("dur"), begin:m.getAttribute("begin")||"0s"});',
'    });',
'    return out;',
'  }',
'  var t0=null, t1=null, t2=null;',
'  setTimeout(function(){ t0=snap(); }, 2500);',
'  setTimeout(function(){ t1=snap(); }, 3400);',
'  setTimeout(function(){ t2=snap(); }, 4300);',
'  setTimeout(function(){',
'    // CSS keyframe animations currently applied',
'    var css=[];',
'    document.querySelectorAll("*").forEach(function(el){',
'      try{ var cs=getComputedStyle(el);',
'        if(cs.animationName && cs.animationName!=="none")',
'          css.push({sel:(el.id?("#"+el.id):el.tagName.toLowerCase()+(el.className&&typeof el.className==="string"?"."+el.className.split(" ")[0]:"")),',
'                    name:cs.animationName, dur:cs.animationDuration, iter:cs.animationIterationCount});',
'      }catch(e){}',
'    });',
'    var moved=0, frozen=0;',
'    if(t0&&t1){ for(var k=0;k<t0.length;k++){',
'      var a=t0[k], b=t1[k];',
'      if(!b) continue;',
'      var d=Math.hypot(a.x-b.x, a.y-b.y);',
'      if(d>0.5) moved++; else frozen++;',
'    }}',
'    var rep={smilTotal:(t0?t0.length:0), moved:moved, frozen:frozen,',
'             sample0:t0?t0.slice(0,6):null, sample1:t1?t1.slice(0,6):null,',
'             cssAnimations:css.slice(0,30), errors:errs};',
'    var x=new XMLHttpRequest(); x.open("POST","/report",true);',
'    x.setRequestHeader("Content-Type","application/json"); x.send(JSON.stringify(rep));',
'  }, 5000);',
'})();',
'<\/script>'
].join('\n');

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
const prof = path.join(os.tmpdir(), 'zia-sm-' + Date.now());
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
  }, 20000);
});
