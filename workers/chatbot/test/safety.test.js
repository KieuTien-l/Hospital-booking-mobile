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
  assert.match(safetyReplyFor('Người nhà bị ngất và không tỉnh'), /cấp cứu/i);
});

test('does not provide diagnoses, medication dosing, or collect secrets', () => {
  assert.match(safetyReplyFor('Tôi uống kháng sinh bao nhiêu viên?'), /không thể chẩn đoán bệnh, kê đơn hoặc hướng dẫn liều dùng thuốc/i);
  assert.match(safetyReplyFor('Bạn chẩn đoán tôi bị bệnh gì đi'), /không thể chẩn đoán bệnh, kê đơn hoặc hướng dẫn liều dùng thuốc/i);
  assert.match(safetyReplyFor('Tôi gửi mã OTP cho bạn nhé'), /không nên gửi mật khẩu, mã OTP/i);
});

test('allows ordinary health and HealWay questions to be answered by the assistant', () => {
  assert.equal(safetyReplyFor('Tôi đau họng 3 ngày, nên khám khoa nào?'), null);
  assert.equal(safetyReplyFor('Tôi bị nôn mửa, cần làm gì?'), null);
  assert.equal(safetyReplyFor('Tôi bị ói mửa từ sáng nay'), null);
  assert.equal(safetyReplyFor('Hướng dẫn tôi đổi lịch khám'), null);
});
