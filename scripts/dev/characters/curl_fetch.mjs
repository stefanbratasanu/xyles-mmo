// Windows transport fallback for Hyper3D's JSON/OAuth requests. Credentials stay
// in process pipes, never command arguments, disk, or logs. No automatic retry.
import { spawn } from 'node:child_process';
const nativeFetch = globalThis.fetch;
const quote = value => '"' + String(value).replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\r', '\\r').replaceAll('\n', '\\n') + '"';
export async function curlFetch(input, init = {}) {
  const request = new Request(input, init);
  const url = new URL(request.url);
  if (process.env.HYPER3D_TRANSPORT_TRACE) console.error(request.method, url.origin + url.pathname);
  if (url.protocol !== 'https:') throw new Error('Only HTTPS is supported.');
  const type = request.headers.get('content-type') || '';
  if (request.body && !type.includes('json') && !type.includes('x-www-form-urlencoded')) return nativeFetch(request);
  let config = `url = ${quote(url.href)}\nrequest = ${quote(request.method)}\n`;
  for (const [name, value] of request.headers) config += `header = ${quote(name + ': ' + value)}\n`;
  if (request.body) config += `data-binary = ${quote(await request.text())}\n`;
  return new Promise((resolve, reject) => {
    const child = spawn('curl.exe', ['--silent', '--show-error', '--max-time', '55', '--include', '--config', '-'], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    const abort = () => { child.kill(); reject(request.signal.reason || new Error('HTTPS request cancelled.')); };
    if (request.signal.aborted) { abort(); return; }
    request.signal.addEventListener('abort', abort, { once: true });
    const chunks = [];
    let errors = '';
    child.stdout.on('data', chunk => chunks.push(chunk));
    child.stderr.on('data', chunk => { errors += chunk.toString(); });
    child.on('error', reject);
    child.on('close', code => {
      request.signal.removeEventListener('abort', abort);
      if (code !== 0) return reject(new Error('HTTPS transport failed: ' + errors.replace(/https?:\/\/\S+/g, '[URL]')));
      let raw = Buffer.concat(chunks);
      let end = raw.indexOf('\r\n\r\n');
      // A proxy may precede the actual response with a CONNECT header block.
      while (end >= 0 && raw.subarray(0, end).toString().includes('Connection established')) { raw = raw.subarray(end + 4); end = raw.indexOf('\r\n\r\n'); }
      if (end < 0) return reject(new Error('Missing HTTPS response headers.'));
      const lines = raw.subarray(0, end).toString().split('\r\n');
      const status = Number(lines.shift().split(' ')[1]);
      if (process.env.HYPER3D_TRANSPORT_TRACE) console.error('HTTPS response', status);
      const headers = new Headers();
      for (const line of lines) { const index = line.indexOf(':'); if (index > 0) headers.append(line.slice(0, index), line.slice(index + 1).trim()); }
      resolve(new Response([204, 205, 304].includes(status) || request.method === 'HEAD' ? null : raw.subarray(end + 4), { status, headers }));
    });
    child.stdin.end(config);
  });
}
globalThis.fetch = curlFetch;
