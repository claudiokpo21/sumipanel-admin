const http = require('http');
const fs = require('fs');
const path = require('path');
const root = path.resolve('C:/Users/Claudiop/Documents/CV Automatizacion');
const mime = { '.html':'text/html; charset=utf-8', '.png':'image/png', '.svg':'image/svg+xml', '.css':'text/css', '.js':'application/javascript' };
http.createServer((req,res)=>{
  let url = decodeURIComponent(req.url.split('?')[0]);
  if(url === '/' || url === '') url = '/index.html';
  const p = path.normalize(path.join(root, url));
  if(!p.startsWith(root)){ res.statusCode=403; res.end('forbidden'); return; }
  fs.stat(p, (e, st) => {
    if(!e && st.isDirectory()){
      const idx = path.join(p, 'index.html');
      if(fs.existsSync(idx)){
        res.setHeader('Content-Type', mime['.html']);
        fs.createReadStream(idx).pipe(res);
        return;
      }
    }
    fs.readFile(p,(err,data)=>{
      if(err){ res.statusCode=404; res.end('not found '+p); return; }
      res.setHeader('Content-Type', mime[path.extname(p)] || 'application/octet-stream');
      res.end(data);
    });
  });
}).listen(8765, '127.0.0.1', ()=>console.log('listening 8765'));
