import { mkdir, writeFile, copyFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';
const root = fileURLToPath(new URL('../', import.meta.url));
const portBase = process.env.SPRINT6_QA_PORT_BASE ? Number(process.env.SPRINT6_QA_PORT_BASE) : null;
if (portBase !== null && (!Number.isInteger(portBase) || portBase < 1024 || portBase > 65000)) throw new Error('Invalid QA port base.');
const freePorts = new Set();
while (freePorts.size < 6 && portBase === null) {
  const server = createServer();
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  freePorts.add(server.address().port);
  await new Promise((resolve) => server.close(resolve));
}
const ports = portBase === null ? [...freePorts] : Array.from({ length: 6 }, (_, i) => portBase + i);
await mkdir(new URL('../build/sprint6-qa/', import.meta.url), { recursive: true });
const config = new URL('../build/sprint6-qa/firebase.qa.json', import.meta.url);
for (const name of ['firestore.rules', 'firestore.indexes.json']) {
  await copyFile(new URL(`../${name}`, import.meta.url), new URL(name, config));
}
await writeFile(config, JSON.stringify({
  functions: { source: '../../functions' },
  firestore: { rules: 'firestore.rules', indexes: 'firestore.indexes.json' },
  emulators: { auth: { host: '127.0.0.1', port: ports[1] }, firestore: { host: '127.0.0.1', port: ports[2], websocketPort: ports[3] },
    functions: { host: '127.0.0.1', port: ports[4] },
    hub: { port: ports[0] }, logging: { port: ports[5] }, ui: { enabled: false }, singleProjectMode: false },
}, null, 2));
const cli = fileURLToPath(new URL('../functions/node_modules/firebase-tools/lib/bin/firebase.js', import.meta.url));
const child = spawn(process.execPath, [cli, 'emulators:exec', '--config', fileURLToPath(config), '--project', 'demo-healway-admin', '--only', 'firestore,auth,functions',
  'node --test functions/test/*.test.js functions/test/emulator/*.test.js test/firestore_rules.test.mjs && node --test functions/test/http/*.test.js'],
  { cwd: root, stdio: 'inherit', env: { ...process.env,
    SPRINT6_ADMIN_TEST_URL: `http://127.0.0.1:${ports[4]}/demo-healway-admin/asia-southeast1/adminCommand`,
  } });
child.on('exit', (code) => { process.exitCode = code ?? 1; });
