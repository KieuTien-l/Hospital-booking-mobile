import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { safetyReplyFor, supportReplyFor, containsSensitiveInfo } from '../src/index.js';
const cases = JSON.parse(await readFile(new URL('./support-questions.json', import.meta.url), 'utf8'));
for (const item of cases) {
  test(`AI-09 ${item.id}: ${item.question}`, () => {
    const actual = containsSensitiveInfo(item.question) ? 'quyền riêng tư' : safetyReplyFor(item.question) ?? supportReplyFor(item.question);
    assert.ok(actual?.includes(item.expected), `Expected ${item.expected}, got ${actual}`);
  });
}
