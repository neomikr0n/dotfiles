/* Interaction tester: drives every button/slider/checkbox in the page from a real
   Firefox instance, capturing any error raised after each interaction.
   Uses the same HTTP-served instrumented page as diag2. */
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');

const target = process.argv[2];
const label = process.argv[3] || 'interact';
const W = +(process.argv[4] || 1440);
const H = +(process.argv[5] || 900);
const PORT = 9100 + Math.floor(Math.random() * 80);

const orig = fs.readFileSync(target, 'utf8');

const hook = `
<script>
(function(){
  window.__diag = {errors:[], console_errors:[]};
  window.addEventListener('error', function(e){ window.__diag.errors.push((e.message||'e')+' @line'+(e.lineno||'?')); }, true);
  window.addEventListener('unhandledrejection', function(e){ window.__diag.errors.push('REJECT: '+((e.reason&&e.reason.message)||e.reason)); });
  var _ce=console.error; console.error=function(){ window.__diag.console_errors.push([].join.call(arguments,' ')); _ce.apply(console,arguments); };

  function snap(){
    var s={};
    // readouts that must change when controls are used
    ['ca-ipeak','ca-pmax','ca-spl','ca-marg','volLab','roVol','roBass','roTreb','roRef','roNoise','gval','gmsg','eqMax','eqMin','eqDem','xCount'].forEach(function(id){
      var el=document.getElementById(id); if(el) s[id]=(el.textContent||'').slice(0,60);
    });
    var g=document.getElementById('gneedle'); if(g) s.gneedle=g.getAttribute('transform');
    var v=document.getElementById('vuNeedle'); if(v) s.vuNeedle=v.getAttribute('transform');
    var tr=document.getElementById('transport'); if(tr) s.transportClass=tr.getAttribute('class');
    var w=document.getElementById('worksvg'); if(w) s.workClass=w.getAttribute('class');
    var ck=document.getElementById('ckPct'); if(ck) s.ckPct=ck.textContent;
    var sq=document.querySelector('.sq'); if(sq) s.sqClass=sq.getAttribute('class');
    var xl=document.getElementById('xlog'); if(xl) s.xlogCount=xl.children.length;
    return s;
  }

  function click(sel){
    var el=document.querySelector(sel);
    if(!el) return 'MISSING:'+sel;
    try{ el.click(); return 'ok'; }catch(e){ return 'THROW:'+e.message; }
  }
  function setSlider(sel,val){
    var el=document.querySelector(sel);
    if(!el) return 'MISSING:'+sel;
    try{ el.value=val; el.dispatchEvent(new Event('input',{bubbles:true}));
      el.dispatchEvent(new Event('change',{bubbles:true})); return 'ok'; }
    catch(e){ return 'THROW:'+e.message; }
  }

  function run(){
    var log=[];
    var before=snap();

    // 1. Aune bias toggle
    log.push(['bias100', click('#bias100')]);
    var afterBias=snap();
    log.push(['bias50', click('#bias50')]);

    // 2. DAC inter-sample dip
    log.push(['dipBtn', click('#dipBtn')]);

    // 3. XLR noise toggle
    log.push(['noiseBtn', click('#noiseBtn')]);

    // 4. Loudness volume slider sweep
    log.push(['volSlider -60', setSlider('#volSlider','-60')]);
    var afterVol60=snap();
    log.push(['volSlider -35', setSlider('#volSlider','-35')]);
    log.push(['volSlider -12', setSlider('#volSlider','-12')]);
    log.push(['volSlider -20', setSlider('#volSlider','-20')]);

    // 5. EQ lab
    log.push(['preV31', click('#preV31')]);
    log.push(['preV4', click('#preV4')]);
    log.push(['bandsBtn', click('#bandsBtn')]);
    document.querySelectorAll('.demo-stage .ctl button').forEach(function(b,i){ try{b.click();}catch(e){} });

    // 6. transport
    log.push(['trUsb', click('#trUsb')]);
    log.push(['trTos', click('#trTos')]);

    // 7. xrun sim
    log.push(['xq4', click('#xq4')]);
    log.push(['xload', click('#xload')]);
    log.push(['xgo', click('#xgo')]);
    log.push(['xq10', click('#xq10')]);
    log.push(['xgo2', click('#xgo')]);

    // 8. energy voltages
    document.querySelectorAll('#energia [data-v]').forEach(function(b,i){
      try{ b.click(); }catch(e){ log.push(['energy'+i,'THROW:'+e.message]); }
    });

    // 9. work route
    log.push(['wkOpt', click('#wkOpt')]);
    log.push(['wkCur', click('#wkCur')]);

    // 10. checklist items
    document.querySelectorAll('#ckList li').forEach(function(li){ try{ li.click(); }catch(e){} });
    var afterCheck=snap();

    // 11. planar controls
    log.push(['planarFreq', setSlider('#planarFreq','9')]);
    log.push(['planarField', click('#planarField')]);
    log.push(['planarField2', click('#planarField')]);

    // 12. rail nav
    document.querySelectorAll('#rail a').forEach(function(a){ try{ a.click(); }catch(e){} });

    var report = {
      interactions: log,
      errors: window.__diag.errors,
      console_errors: window.__diag.console_errors,
      readoutChanges: {
        ca_ipeak_before: before['ca-ipeak'], ca_ipeak_after_bias100: afterBias['ca-ipeak'],
        ca_spl: afterBias['ca-spl'],
        vol_before: before['volLab'], vol_after_m60: afterVol60['volLab'],
        gval_before: before['gval'],
        ckPct_after_clicks: afterCheck['ckPct'],
        gneedle: afterCheck['gneedle'], vuNeedle: afterCheck['vuNeedle'],
        transportClass: afterCheck['transportClass'], workClass: afterCheck['workClass'],
        sqClass: afterCheck['sqClass'], xlogCount: afterCheck['xlogCount'],
        eqMax: afterCheck['eqMax'], eqMin: afterCheck['eqMin'], eqDem: afterCheck['eqDem'],
      },
      finalCanvasBlank: (function(){
        var out=[]; document.querySelectorAll('canvas').forEach(function(c){
          try{ var g=c.getContext('2d'); var d=g.getImageData(0,0,Math.min(c.width,300),Math.min(c.height,300)).data;
            var nz=0; for(var i=3;i<d.length;i+=4) if(d[i]!==0) nz++;
            if(nz===0) out.push(c.id||'(none)');
          }catch(e){ out.push('ERR:'+(c.id||'?')); } });
        return out; })()
    };
    try{
      var x=new XMLHttpRequest(); x.open('POST','/report',true);
      x.setRequestHeader('Content-Type','application/json'); x.send(JSON.stringify(report));
    }catch(e){}
  }
  setTimeout(run, 2500);
})();
</script>
`;

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
let reportData = null;

const server = http.createServer((req, res) => {
  if (req.url === '/report' && req.method === 'POST') {
    let b=''; req.on('data',c=>b+=c); req.on('end',()=>{reportData=b;res.writeHead(200);res.end('ok');});
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(injected);
});

const prof = path.join(os.tmpdir(), 'zia-i-'+label+'-'+Date.now());
fs.mkdirSync(prof, { recursive: true });

server.listen(PORT, '127.0.0.1', () => {
  const env = Object.assign({}, process.env, {
    DBUS_SESSION_BUS_ADDRESS: 'disabled:', NO_AT_BRIDGE: '1',
    MOZ_HEADLESS: '1', MOZ_DISABLE_CONTENT_SANDBOX: '1',
  });
  const child = spawn('/usr/lib/firefox/firefox', [
    '--headless','--no-remote','--window-size', W+','+H,
    '--profile', prof, 'http://127.0.0.1:'+PORT+'/index.html',
  ], { env, stdio: ['ignore','ignore','ignore'] });
  const t = setTimeout(()=>{ try{child.kill('SIGKILL')}catch(e){} server.close();
    console.log(reportData ? reportData : '===NO_REPORT==='); process.exit(0); }, 30000);
  child.on('exit', ()=>{ clearTimeout(t); server.close();
    console.log(reportData ? reportData : '===NO_REPORT==='); process.exit(0); });
});
