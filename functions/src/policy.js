export class AdminError extends Error {
  constructor(message, code = 'failed-precondition') { super(message); this.code = code; }
}
export const fail = (message, code) => { throw new AdminError(message, code); };
export const text = (value, label, max = 1000, required = true) => {
  if (typeof value !== 'string') {
    if (!required && value == null) return '';
    fail(`${label} không hợp lệ.`, 'invalid-argument');
  }
  const result = value.trim();
  if ((required && !result) || result.length > max) fail(`${label} bắt buộc, tối đa ${max} ký tự.`, 'invalid-argument');
  return result;
};
export const id = (value, label = 'Mã bản ghi') => {
  const result = text(value, label, 128);
  if (result.includes('/') || result === '.' || result === '..') fail(`${label} không hợp lệ.`, 'invalid-argument');
  return result;
};
export const number = (value, label, min = 0, max = 100000000, integer = false) => {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max || (integer && !Number.isInteger(value))) {
    fail(`${label} phải từ ${min} đến ${max}${integer ? ' và là số nguyên' : ''}.`, 'invalid-argument');
  }
  return value;
};
export const choice = (value, choices, label = 'Trạng thái') => {
  if (!choices.includes(value)) fail(`${label} không hợp lệ.`, 'invalid-argument');
  return value;
};
export const email = (value) => {
  const result = text(value, 'Email', 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result)) fail('Email không hợp lệ.', 'invalid-argument');
  return result;
};
export const date = (value) => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail('Ngày phải theo dạng YYYY-MM-DD.', 'invalid-argument');
  const parsed = new Date(`${value}T00:00:00+07:00`);
  if (!Number.isFinite(parsed.getTime()) || dayKey(parsed) !== value) fail('Ngày không hợp lệ.', 'invalid-argument');
  return parsed;
};
export const dayKey = (value) => {
  const d = value?.toDate ? value.toDate() : value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(d.getTime())) fail('Ngày dữ liệu chưa hợp lệ.');
  return new Date(d.getTime() + 7 * 3600000).toISOString().slice(0, 10);
};
export const minutes = (value) => {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) fail('Giờ phải theo dạng HH:mm.', 'invalid-argument');
  return Number(value.slice(0, 2)) * 60 + Number(value.slice(3));
};
export const timeText = (value) => `${Math.floor(value / 60)}`.padStart(2, '0') + ':' + `${value % 60}`.padStart(2, '0');
export const workPeriod = (workDate, startTime, endTime) => {
  const day = date(workDate), start = minutes(startTime), end = minutes(endTime);
  if (start >= end) fail('Giờ kết thúc phải sau giờ bắt đầu.', 'invalid-argument');
  const weekday = new Date(day.getTime() + 7 * 3600000).getUTCDay();
  if (weekday === 0 || (weekday === 6 && end > 720)) fail('Chủ nhật không có lịch; thứ bảy chỉ khám trước 12:00.', 'invalid-argument');
  return { day, start, end };
};
export const bookingTime = (workDate, startTime) => {
  const d = date(dayKey(workDate));
  return new Date(d.getTime() + minutes(startTime) * 60000);
};
export const terminal = (status) => ['CANCELLED', 'COMPLETED', 'NO_SHOW'].includes(status);
export const heldStatuses = new Set(['PENDING', 'CONFIRMED', 'COMPLETED', 'NO_SHOW']);
export const transition = (before, after) => {
  const allowed = { PENDING: ['CONFIRMED', 'CANCELLED'], CONFIRMED: ['CANCELLED', 'NO_SHOW'] };
  if (!allowed[before]?.includes(after)) fail('Trạng thái đã thay đổi hoặc thao tác không được phép.');
};
export const capacityChange = (slot, delta) => {
  const capacity = number(slot.capacity, 'Sức chứa', 1, 100, true);
  const before = number(slot.bookedCount, 'Số chỗ đã đặt', 0, capacity, true);
  const count = before + delta;
  if (count < 0 || count > capacity) fail('Ca khám không còn đủ chỗ hoặc bộ đếm chưa nhất quán.');
  return { bookedCount: count, status: ['UNAVAILABLE', 'CANCELLED'].includes(slot.status) ? slot.status : count >= capacity ? 'BOOKED' : 'AVAILABLE' };
};
const schemas = {
  CHUYEN_KHOA: { name: 'name', description: 'optional' },
  BAC_SI: { fullName: 'name', email: 'optionalEmail', phone: 'phone', dateOfBirth: 'optionalDate', gender: 'optional', address: 'optional', specialtyId: 'id', qualification: 'optional', yearsOfExperience: 'years', consultationFee: 'money', biography: 'optional', avatarUrl: 'url' },
  BENH_NHAN: { fullName: 'name', phone: 'phone', email: 'optionalEmail', dateOfBirth: 'optionalDate', gender: 'optional', address: 'optional', nationalId: 'optional', insuranceNumber: 'optional' },
};
export function cleanFields(collection, input, create = false) {
  const schema = schemas[collection];
  if (!schema || !input || Array.isArray(input) || typeof input !== 'object') fail('Dữ liệu không hợp lệ.', 'invalid-argument');
  const result = {};
  for (const [key, value] of Object.entries(input)) {
    if (!Object.hasOwn(schema, key)) fail(`Không được sửa trường ${key}.`, 'invalid-argument');
    switch (schema[key]) {
      case 'name': result[key] = text(value, 'Họ tên / tên', 120); break;
      case 'id': result[key] = id(value); break;
      case 'money': result[key] = number(value, 'Phí khám'); break;
      case 'years': result[key] = number(value, 'Số năm kinh nghiệm', 0, 70, true); break;
      case 'phone': result[key] = text(value, 'Điện thoại', 20, false); if (result[key] && !/^\+?[\d ()-]{8,20}$/.test(result[key])) fail('Số điện thoại không hợp lệ.', 'invalid-argument'); break;
      case 'optionalEmail': result[key] = value ? email(value) : ''; break;
      case 'optionalDate': result[key] = value ? date(value) : null; if (result[key] && result[key] > new Date()) fail('Ngày sinh không được ở tương lai.', 'invalid-argument'); break;
      case 'url': result[key] = text(value, key, 2048, false); if (result[key] && !/^https:\/\//.test(result[key])) fail('Ảnh phải dùng URL HTTPS.', 'invalid-argument'); break;
      default: result[key] = text(value, key, 2000, false);
    }
  }
  if (create) {
    if (!result[collection === 'CHUYEN_KHOA' ? 'name' : 'fullName']) fail('Thiếu họ tên / tên.', 'invalid-argument');
    if (collection === 'BAC_SI' && (!result.specialtyId || result.consultationFee == null || result.yearsOfExperience == null)) fail('Thiếu chuyên khoa, kinh nghiệm hoặc phí khám.', 'invalid-argument');
  }
  return result;
}
