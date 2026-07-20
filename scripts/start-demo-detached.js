#!/usr/bin/env node

import { spawn } from 'child_process';
import { closeSync, mkdirSync, openSync } from 'fs';
import { dirname, resolve } from 'path';

const [demoPath, logPath] = process.argv.slice(2);

if (!demoPath || !logPath) {
  console.error('Usage: start-demo-detached.js <demo-path> <log-path>');
  process.exit(2);
}

const resolvedDemoPath = resolve(demoPath);
const resolvedLogPath = resolve(logPath);
mkdirSync(dirname(resolvedLogPath), { recursive: true });

const logFd = openSync(resolvedLogPath, 'a');
const child = spawn(process.execPath, [resolvedDemoPath], {
  cwd: process.cwd(),
  detached: true,
  env: { ...process.env },
  stdio: ['ignore', logFd, logFd],
});

try {
  await new Promise((resolveSpawn, rejectSpawn) => {
    child.once('spawn', resolveSpawn);
    child.once('error', rejectSpawn);
  });
} catch (error) {
  closeSync(logFd);
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

child.unref();
closeSync(logFd);

if (!child.pid) {
  console.error('Detached demo process did not report a PID');
  process.exit(1);
}

console.log(child.pid);
