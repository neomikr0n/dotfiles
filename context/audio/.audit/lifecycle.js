/* Scroll lifecycle test: verify every canvas draws when in view, pauses when out,
   and RESUMES (not stays blank) when scrolled back. This is the real gating contract. */
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const http = require('http');

const target = process.argv[2];
const label = process.argv[3] || 'lifecycle';
const W = +(process.argv[4] || 1440);
const H = +(process.argv[5] || 900);
const PORT = 9200 + Math.floor(Math.random() * 80);

const orig = fs.readFileSync(target, 'utf8');

const hook = `
<script>
(function(){
  var diag={errors:[],console_errors:[]};
  window.addEventListener('error',function(e){diag.errors.push((e.message||'e')+' @'+e.lineno);},true);
  var _ce=console.error; console.error=function(){diag.console_errors.push([].join.call(arguments,' '));_ce.apply(console,arguments);};

  var IDS=['embers','scope','planar','classa','dacpipe','xlrnoise','loudness','eqlab','xrun'];
  function isBlank(id){
    var c=document.getElementById(id); if(!c) return 'MISSING';
    try{
      var g=c.getContext('2d');
      if(!c.width||!c.height) return 'ZERO_SIZE';
      var d=g.getImageData(0,0,Math.min(c.width,400),Math.min(c.height,400)).data;
      var nz=0; for(var i=3;i<d.length;i+=4) if(d[i]!==0) nz++;
      return nz===0 ? 'BLANK' : 'DRAWN';
    }catch(e){ return 'ERR:'+e.message; }
  }
  function inView(id){
    var c=document.getElementById(id); if(!c) return false;
    var r=c.getBoundingClientRect();
    return r.bottom>-120 && r.top<innerHeight+120;
  }
  function wait(ms){ return new Promise(function(r){ setTimeout(r,ms); }); }

  async function cycle(id){
    var el=document.getElementById(id); if(!el) return {id:id, state:'MISSING'};
    // scroll the canvas into view
    var y=el.getBoundingClientRect().top+window.pageYOffset-(innerHeight/2);
    window.scrollTo(0,y);
    await wait(900);
    var drawn=isBlank(id);
    // scroll far away
    window.scrollTo(0,0);
    await wait(700);
    var offscreen=isBlank(id);
    // scroll back
    window.scrollTo(0,y);
    await wait(900);
    var resumed=isBlank(id);
    return {id:id, afterEnter:drawn, afterLeave:offscreen, afterReturn:resumed, inView:inView(id)};
  }

  async function run(){
    var results=[];
    for(var i=0;i<IDS.length;i++){
      results.push(await cycle(IDS[i]));
    }
    var rep={results:results, errors:diag.errors, console_errors:diag.console_errors};
    try{ var x=new XMLHttpRequest(); x.open('POST','/report',true);
      x.setRequestHeader('Content-Type','application/json'); x.send(JSON.stringify(rep)); }catch(e){}
  }
  setTimeout(run,2200);
})();
</script>
`;

const injected = orig.replace(/<head([^>]*)>/i, '<head$1>' + hook);
let reportData=null;
const server=http.createServer((req,res)=>{
  if(req.url==='/report'&&req.method==='POST'){let b='';req.on('data',c=>b+=c);req.on('end',()=>{reportData=b;res.writeHead(200);res.end('ok');});return;}
  res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'}); res.end(injected);
});
const prof=path.join(os.tmpdir(),'zia-l-'+label+'-'+Date.now()); fs.mkdirSync(prof,{recursive:true});

server.listen(PORT,'127.0.0.1',()=>{
  const env=Object.assign({},process.env,{DBUS_SESSION_BUS_ADDRESS:'disabled:',NO_AT_BRIDGE:'1',MOZ_HEADLESS:'1',MOZ_DISABLE_CONTENT_SANDBOX:'1'});
  const child=spawn('/usr/lib/firefox/firefox',['--headless','--no-remote','--window-size',W+','+H,'--profile',prof,'http://127.0.0.1:'+PORT+'/index.html'],{env,stdio:['ignore','ignore','ignore']});
  const t=setTimeout(()=>{try{child.kill('SIGKILL')}catch(e){} server.close(); console.log(reportData||'===NO_REPORT==='); process.exit(0);},70000);
  child.on('exit',()=>{clearTimeout(t);server.close();console.log(reportData||'===NO_REPORT===');process.exit(0);});
});
