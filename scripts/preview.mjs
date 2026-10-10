import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const root = resolve('build/web');
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf','.otf':'font/otf'};
const server = http.createServer(async (request,response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
    let path = resolve(root, '.'+pathname);
    if (path !== root && !path.startsWith(root+sep)) { response.writeHead(403).end();return; }
    if ((await stat(path)).isDirectory()) path=resolve(path,'index.html');
    const bytes = await readFile(path);
    response.writeHead(200, {'Content-Type':mime[extname(path)]??'application/octet-stream','Cache-Control':'no-cache'});
    response.end(bytes);
  } catch { response.writeHead(404).end('Not found'); }
});
const port=Number(process.env.VITALOG_PORT??8766);
server.listen(port,'127.0.0.1',()=>console.log(`Vitalog preview: http://localhost:${port}/?demo=1`));
