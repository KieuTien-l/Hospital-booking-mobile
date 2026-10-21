import test from 'node:test';
import assert from 'node:assert/strict';
import { workPeriod, capacityChange, transition, cleanFields, date, dayKey, bookingTime } from '../src/policy.js';

test('work schedules reject invalid times, Sundays and Saturday afternoons', () => {
  assert.throws(() => workPeriod('2026-10-25', '08:00', '09:00'));
  assert.throws(() => workPeriod('2026-10-24', '11:00', '13:00'));
  assert.throws(() => workPeriod('2026-10-23', '09:00', '08:00'));
  assert.throws(() => workPeriod('2026-10-23', '24:00', '25:00'));
  assert.equal(workPeriod('2026-10-24', '08:00', '12:00').end, 720);
  assert.equal(dayKey(date('2026-10-21')), '2026-10-21');
  assert.equal(bookingTime(date('2026-10-21'), '08:30').toISOString(), '2026-10-21T01:30:00.000Z');
});
test('capacity changes preserve locks and reject underflow, overflow or missing counters', () => {
  assert.deepEqual(capacityChange({ capacity: 5, bookedCount: 4, status: 'AVAILABLE' }, 1), { bookedCount: 5, status: 'BOOKED' });
  assert.deepEqual(capacityChange({ capacity: 5, bookedCount: 4, status: 'UNAVAILABLE' }, -2), { bookedCount: 2, status: 'UNAVAILABLE' });
  assert.throws(() => capacityChange({ capacity: 5, bookedCount: 4 }, 2));
  assert.throws(() => capacityChange({ capacity: 5, bookedCount: 1 }, -2));
  assert.throws(() => capacityChange({ capacity: 5 }, 1));
});
test('administrative transitions cannot fake completion or reopen terminal appointments', () => {
  assert.doesNotThrow(() => transition('PENDING', 'CONFIRMED'));
  assert.doesNotThrow(() => transition('CONFIRMED', 'CANCELLED'));
  assert.throws(() => transition('PENDING', 'COMPLETED'));
  assert.throws(() => transition('CANCELLED', 'PENDING'));
  assert.throws(() => transition('COMPLETED', 'CANCELLED'));
});
test('doctor profile whitelist keeps login ownership and role out of editable fields', () => {
  assert.throws(() => cleanFields('BAC_SI', { role: 'admin' }));
  assert.throws(() => cleanFields('BAC_SI', { userId: 'another-user' }));
  assert.throws(() => cleanFields('BAC_SI', { consultationFee: -1 }));
  assert.throws(() => cleanFields('BAC_SI', { avatarUrl: 'javascript:evil' }));
  assert.throws(() => cleanFields('BAC_SI', { dateOfBirth: '2026-02-31' }));
  assert.deepEqual(cleanFields('BAC_SI', { fullName: '  BS An ', email: 'Contact@Example.com', dateOfBirth: '' }), { fullName: 'BS An', email: 'contact@example.com', dateOfBirth: null });
});
