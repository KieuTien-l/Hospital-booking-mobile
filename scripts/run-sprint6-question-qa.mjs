import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { safetyReplyFor, supportReplyFor, containsSensitiveInfo } from '../workers/chatbot/src/index.js';

const cases = JSON.parse(await readFile(new URL('../workers/chatbot/test/support-questions.json', import.meta.url), 'utf8'));
const results = cases.map((item) => {
  const actual = containsSensitiveInfo(item.question) ? 'Từ chối: bảo vệ quyền riêng tư; không gửi tới AI hoặc lưu hội thoại.' : safetyReplyFor(item.question) ?? supportReplyFor(item.question);
  return { ...item, actual, result: actual?.includes(item.expected) ? 'PASS' : 'FAIL' };
});
const directory = new URL('../docs/qa/sprint6/', import.meta.url);
await mkdir(directory, { recursive: true });
await writeFile(new URL('questions-results.json', directory), JSON.stringify({ generatedAt: new Date().toISOString(), method: 'Deterministic application guidance and safety routes, no live model call', results }, null, 2) + '\n');
await writeFile(new URL('questions-results.md', directory), '# AI-09: Kết quả bộ câu hỏi HealWay\n\nĐánh giá tự động phần hướng dẫn ứng dụng và bộ lọc an toàn; không phải đánh giá mô hình AI trực tiếp.\n\n| ID | Câu hỏi | Mong đợi có nội dung | Actual result | Kết quả |\n| --- | --- | --- | --- | --- |\n' + results.map((r) => `| ${r.id} | ${r.question} | ${r.expected} | ${r.actual ?? 'Chuyển tới mô hình'} | ${r.result} |`).join('\n') + '\n');
console.log(`${results.filter((r) => r.result === 'PASS').length}/${results.length} questions PASS`);
if (results.some((r) => r.result === 'FAIL')) process.exitCode = 1;
