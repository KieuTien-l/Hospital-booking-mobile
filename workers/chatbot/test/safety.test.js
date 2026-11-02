import assert from 'node:assert/strict';
import test from 'node:test';

import { safetyReplyFor } from '../src/index.js';

test('declines requests outside HealWay and general health', () => {
  assert.match(safetyReplyFor('Viết code Flutter đăng nhập Firebase'), /chỉ hỗ trợ sử dụng HealWay/i);
  assert.match(safetyReplyFor('Hôm nay giá vàng bao nhiêu?'), /chỉ hỗ trợ sử dụng HealWay/i);
  assert.match(safetyReplyFor('Giải bài toán này giúp tôi'), /chỉ hỗ trợ sử dụng HealWay/i);
  assert.match(safetyReplyFor('Beat It là bài j?'), /chỉ hỗ trợ sử dụng HealWay/i);
  assert.match(safetyReplyFor('Thủ đô của Pháp là gì?'), /chỉ hỗ trợ sử dụng HealWay/i);
  assert.match(safetyReplyFor('Kể cho tôi một câu chuyện'), /chỉ hỗ trợ sử dụng HealWay/i);
});

test('routes urgent symptoms to emergency care', () => {
  assert.match(safetyReplyFor('Tôi đau ngực dữ dội và khó thở'), /cấp cứu/i);
  assert.match(safetyReplyFor('Tôi đau thắt ngực, khó thở'), /cấp cứu/i);
  assert.match(safetyReplyFor('Người nhà bị ngất và không tỉnh'), /cấp cứu/i);
});

test('allows non-emergency health questions to reach the AI', () => {
  assert.equal(safetyReplyFor('Tôi bị đau ngực thì nên khám chuyên khoa nào?'), null);
  assert.equal(safetyReplyFor('Tôi uống kháng sinh bao nhiêu viên?'), null);
  assert.equal(safetyReplyFor('Bạn chẩn đoán tôi bị bệnh gì đi'), null);
  assert.equal(safetyReplyFor('Tôi thấy người rất mệt, nên làm sao?'), null);
});

test('blocks secret input before it reaches the AI', () => {
  assert.match(safetyReplyFor('Tôi gửi mã OTP cho bạn nhé'), /không nên gửi mật khẩu, mã OTP/i);
});

test('allows ordinary health and HealWay questions to be answered by the assistant', () => {
  assert.equal(safetyReplyFor('Tôi đau họng 3 ngày, nên khám khoa nào?'), null);
  assert.equal(safetyReplyFor('Tôi bị nôn mửa, cần làm gì?'), null);
  assert.equal(safetyReplyFor('Tôi bị ói mửa từ sáng nay'), null);
  assert.equal(safetyReplyFor('Hướng dẫn tôi đổi lịch khám'), null);
  assert.equal(
    safetyReplyFor('Tôi cần chuẩn bị những gì trước khi đi khám?'),
    null,
  );
  assert.equal(
    safetyReplyFor('Đi khám cần mang theo giấy tờ gì?'),
    null,
  );
});

test('allows natural follow-up and health questions without keyword gating', () => {
  assert.equal(
    safetyReplyFor('Có nguy hiểm không?', [
      { role: 'user', text: 'Tôi bị tiêu chảy hai ngày.' },
      { role: 'assistant', text: 'Bạn nên theo dõi triệu chứng.' },
      { role: 'user', text: 'Có nguy hiểm không?' },
    ]),
    null,
  );
});
