import { mkdir, writeFile, copyFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
await mkdir(new URL('../build/sprint6-qa/', import.meta.url), { recursive: true });
const config = new URL('../build/sprint6-qa/firebase.qa.json', import.meta.url);
for (const name of ['firestore.rules', 'firestore.indexes.json']) {
  await copyFile(new URL(`../${name}`, import.meta.url), new URL(name, config));
}
await writeFile(config, JSON.stringify({
  firestore: { rules: 'firestore.rules', indexes: 'firestore.indexes.json' },
  emulators: { auth: { host: '127.0.0.1', port: 9399 }, firestore: { host: '127.0.0.1', port: 9380, websocketPort: 9351 },
    hub: { port: 9340 }, logging: { port: 9350 }, ui: { enabled: false }, singleProjectMode: false },
}, null, 2));
const cli = fileURLToPath(new URL('../functions/node_modules/firebase-tools/lib/bin/firebase.js', import.meta.url));
const child = spawn(process.execPath, [cli, 'emulators:exec', '--config', fileURLToPath(config), '--project', 'demo-healway-admin', '--only', 'firestore,auth',
  'node --test functions/test/*.test.js functions/test/emulator/*.test.js test/firestore_rules.test.mjs'], { cwd: root, stdio: 'inherit' });
child.on('exit', (code) => { process.exitCode = code ?? 1; });
