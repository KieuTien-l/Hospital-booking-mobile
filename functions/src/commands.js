import { createHash, randomBytes } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { AdminError, fail, text, id, number, choice, email, date, dayKey, minutes, timeText, workPeriod, bookingTime, transition, capacityChange, cleanFields, heldStatuses } from './policy.js';

const stamp = () => FieldValue.serverTimestamp();
const canonical = (v) => Array.isArray(v) ? v.map(canonical) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canonical(v[k])])) : v;
const digest = (value) => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const snapshotData = (snapshot) => { if (!snapshot.exists) fail('Bản ghi không còn tồn tại.', 'not-found'); return snapshot.data(); };
const future = (schedule, startTime) => { if (bookingTime(schedule.workDate, startTime) <= new Date()) fail('Thời gian khám đã qua.'); };
const active = (data, label) => { if (data.status !== 'ACTIVE' || data.isActive === false || data.acceptingBookings === false) fail(`${label} đã ngừng nhận lịch hoặc không hoạt động.`); };

/** Every write, its audit and its idempotency receipt share the same transaction. */
export async function executeAdminCommand(db, auth, uid, input) {
  id(uid, 'Tài khoản');
  if (!input || typeof input !== 'object' || JSON.stringify(input).length > 30000) fail('Yêu cầu không hợp lệ.', 'invalid-argument');
  const requestId = id(input.requestId, 'Mã yêu cầu');
  const operation = text(input.operation, 'Thao tác', 60);
  text(input.reason, 'Lý do', 500);
  const actor = snapshotData(await db.collection('TAI_KHOAN').doc(uid).get());
  if (actor.role !== 'admin' || actor.isActive !== true) fail('Chỉ quản trị viên đang hoạt động được thực hiện.', 'permission-denied');
  if (operation === 'createDoctor') return provisionDoctor(db, auth, uid, input);
  const receiptRef = db.collection('ADMIN_COMMANDS').doc(`${uid}_${requestId}`);
  const fingerprint = digest(input);
  return db.runTransaction(async (tx) => {
    const currentActor = snapshotData(await tx.get(db.collection('TAI_KHOAN').doc(uid)));
    if (currentActor.role !== 'admin' || currentActor.isActive !== true) fail('Phiên admin không còn quyền.', 'permission-denied');
    const receipt = await tx.get(receiptRef);
    if (receipt.exists) {
      if (receipt.data().fingerprint !== fingerprint) fail('Mã yêu cầu đã dùng cho nội dung khác.', 'already-exists');
      return receipt.data().result;
    }
    const context = new CommandContext(db, tx, uid, requestId, input, auth);
    const result = await context.execute();
    tx.create(receiptRef, { fingerprint, result, createdAt: stamp() });
    return result;
  });
}

class CommandContext {
  constructor(db, tx, uid, requestId, input, auth) { Object.assign(this, { db, tx, uid, requestId, input, auth }); }
  ref(collection, key) { return this.db.collection(collection).doc(id(key)); }
  async get(collection, key) {
    const value = snapshotData(await this.tx.get(this.ref(collection, key)));
    if (collection === this.input.collection && key === this.input.id && this.input.expectedUpdatedAt != null && value.updatedAt?.toMillis?.() !== this.input.expectedUpdatedAt) {
      fail('Bản ghi đã thay đổi. Đóng chi tiết và mở lại trước khi sửa.', 'aborted');
    }
    return value;
  }
  async rows(collection, field, value, limit = 300) {
    const result = await this.tx.get(this.db.collection(collection).where(field, '==', value).limit(limit + 1));
    if (result.size > limit) fail('Có quá nhiều bản ghi liên quan; cần chia nhỏ thao tác.');
    return result.docs;
  }
  reason() { return text(this.input.reason, 'Lý do', 500); }
  audit(collection, key, before, after, action = this.input.operation) {
    this.tx.create(this.db.collection('NHAT_KY_ADMIN').doc(this.requestId), {
      actorId: this.uid, targetCollection: collection, targetId: key, action,
      reason: this.input.reason || '', before: before || null, after: after || null, createdAt: stamp(),
    });
  }
  updated(collection, key, before, changes) {
    this.tx.update(this.ref(collection, key), { ...changes, updatedAt: stamp() });
    this.audit(collection, key, before, changes);
    return { id: key, collection, message: 'Đã cập nhật.' };
  }
  async ensureUnused(collection, key, dependencies) {
    for (const [related, field] of dependencies) {
      const docs = await this.rows(related, field, key, 1);
      if (docs.length) fail('Đã có dữ liệu liên quan. Hãy ngừng hoạt động / lưu trữ thay vì xóa.');
    }
  }
  notification(key, patient, patientId, title, content, appointmentId = null) {
    this.tx.create(this.db.collection('THONG_BAO').doc(`${this.requestId}_${key}`), {
      title, content, patientId, userId: patient.authUserId || null, appointmentId,
      status: 'SENT', channel: 'in_app', isRead: false, createdAt: stamp(), createdBy: this.uid,
    });
  }
  async execute() {
    switch (this.input.operation) {
      case 'create': return this.create();
      case 'save': return this.save();
      case 'delete': return this.remove();
      case 'setAvailability': return this.availability();
      case 'createSchedule': return this.schedule(false);
      case 'editSchedule': return this.schedule(true);
      case 'saveSlot': return this.slot();
      case 'book': return this.book();
      case 'appointmentStatus': return this.appointmentStatus();
      case 'reschedule': return this.reschedule();
      case 'internalNote': return this.internalNote();
      case 'accountAccess': return this.accountAccess();
      case 'passwordSetup': return this.passwordSetup();
      case 'feedback': return this.feedback();
      case 'notificationDraft': return this.notificationDraft();
      case 'sendNotification': return this.sendNotification();
      case 'paymentReview': return this.paymentReview();
      case 'saveSettings': return this.settings();
      case 'reviewDoctorRequest': return this.reviewDoctorRequest();
      default: fail('Thao tác chưa được hỗ trợ.', 'invalid-argument');
    }
  }
  async reviewDoctorRequest() {
    const key = id(this.input.id), before = await this.get('YEU_CAU_BAC_SI', key);
    if (before.status !== 'PENDING') fail('Yêu cầu đã được xử lý.', 'failed-precondition');
    const values = this.input.values || {};
    const status = choice(values.status, ['APPROVED', 'REJECTED', 'RESOLVED'], 'Kết quả xử lý');
    const adminResponse = text(values.adminResponse, 'Phản hồi bác sĩ', 1000);
    return this.updated('YEU_CAU_BAC_SI', key, before,
      { status, adminResponse, reviewedBy: this.uid, reviewedAt: stamp() });
  }
  async create() {
    const collection = choice(this.input.collection, ['CHUYEN_KHOA', 'BENH_NHAN'], 'Danh mục');
    const values = { ...this.input.values };
    const owner = values.authUserId;
    delete values.authUserId;
    const fields = cleanFields(collection, values, true);
    if (collection === 'BENH_NHAN') {
      const account = await this.get('TAI_KHOAN', owner);
      if (account.role !== 'patient' || !account.isActive) fail('Chọn tài khoản bệnh nhân đang hoạt động.');
      fields.authUserId = owner;
    }
    fields.status = 'ACTIVE'; fields.isActive = true;
    const key = this.requestId;
    this.tx.create(this.ref(collection, key), { ...fields, createdAt: stamp(), updatedAt: stamp() });
    this.audit(collection, key, null, fields);
    return { id: key, collection, message: 'Đã tạo bản ghi.' };
  }
  async save() {
    const collection = choice(this.input.collection, ['CHUYEN_KHOA', 'BAC_SI', 'BENH_NHAN'], 'Danh mục');
    const key = id(this.input.id), before = await this.get(collection, key);
    const fields = cleanFields(collection, this.input.values);
    this.reason();
    if (collection === 'BAC_SI') {
      if (fields.specialtyId) active(await this.get('CHUYEN_KHOA', fields.specialtyId), 'Chuyên khoa');
      const account = before.userId ? await this.get('TAI_KHOAN', before.userId) : null;
      if (account && (fields.fullName || fields.phone != null)) {
        this.tx.update(this.ref('TAI_KHOAN', before.userId), {
          ...(fields.fullName ? { fullName: fields.fullName } : {}),
          ...(fields.phone != null ? { phone: fields.phone } : {}), updatedAt: stamp(),
        });
      }
    }
    return this.updated(collection, key, before, fields);
  }
  async remove() {
    const collection = choice(this.input.collection, ['CHUYEN_KHOA', 'BAC_SI', 'LICH_LAM_VIEC', 'CA_KHAM', 'THONG_BAO'], 'Danh mục');
    const key = id(this.input.id), before = await this.get(collection, key);
    this.reason();
    const deps = {
      CHUYEN_KHOA: [['BAC_SI', 'specialtyId'], ['LICH_HEN', 'specialtyId']],
      BAC_SI: [['LICH_HEN', 'doctorId'], ['LICH_LAM_VIEC', 'doctorId'], ['HO_SO_SUC_KHOE', 'doctorId'], ['KET_QUA_CLS', 'doctorId']],
      LICH_LAM_VIEC: [['LICH_HEN', 'workScheduleId']],
      CA_KHAM: [['LICH_HEN', 'timeSlotId']], THONG_BAO: [],
    };
    await this.ensureUnused(collection, key, deps[collection]);
    const unusedSlots = collection === 'LICH_LAM_VIEC' ? await this.rows('CA_KHAM', 'workScheduleId', key) : [];
    if (unusedSlots.some((slot) => slot.data().bookedCount !== 0)) fail('Lịch còn ca đã giữ chỗ hoặc thiếu bộ đếm. Không thể xóa.');
    if (collection === 'THONG_BAO' && before.status !== 'DRAFT') fail('Chỉ được xóa thông báo nháp.');
    if (collection === 'CA_KHAM' && before.bookedCount !== 0) fail('Ca khám còn chỗ đã giữ hoặc thiếu bộ đếm; không thể xóa.');
    if (collection === 'BAC_SI' && before.userId) {
      await this.get('TAI_KHOAN', before.userId);
      this.tx.update(this.ref('TAI_KHOAN', before.userId), { isActive: false, status: 'INACTIVE', updatedAt: stamp() });
    }
    this.tx.create(this.db.collection('ADMIN_ARCHIVES').doc(this.requestId), { collection, id: key, data: before, actorId: this.uid, createdAt: stamp() });
    for (const slot of unusedSlots) this.tx.delete(slot.ref);
    this.tx.delete(this.ref(collection, key));
    this.audit(collection, key, before, null);
    return { id: key, collection, message: collection === 'BAC_SI' ? 'Đã xóa hồ sơ chưa sử dụng và khóa tài khoản liên kết.' : 'Đã xóa bản ghi chưa sử dụng.' };
  }
  async availability() {
    const collection = choice(this.input.collection, ['BAC_SI', 'CHUYEN_KHOA', 'BENH_NHAN', 'LICH_LAM_VIEC', 'CA_KHAM'], 'Danh mục');
    const key = id(this.input.id), before = await this.get(collection, key);
    this.reason();
    const enabled = this.input.values?.enabled;
    if (typeof enabled !== 'boolean') fail('Thiếu trạng thái bật/tắt.', 'invalid-argument');
    if (collection === 'CHUYEN_KHOA' && !enabled) {
      const doctors = await this.rows('BAC_SI', 'specialtyId', key);
      if (doctors.some((doctor) => doctor.data().isActive !== false && doctor.data().status !== 'INACTIVE')) {
        fail('Không thể ngừng hoạt động chuyên khoa đang có bác sĩ hoạt động.');
      }
    }
    if (collection === 'BAC_SI') return this.updated(collection, key, before, { acceptingBookings: enabled });
    if (collection === 'BENH_NHAN') return this.updated(collection, key, before, { status: enabled ? 'ACTIVE' : 'ARCHIVED', isActive: enabled });
    if (collection === 'CA_KHAM') {
      const counts = capacityChange(before, 0);
      return this.updated(collection, key, before, { status: enabled ? counts.bookedCount >= before.capacity ? 'BOOKED' : 'AVAILABLE' : 'UNAVAILABLE' });
    }
    const affected = collection === 'LICH_LAM_VIEC' ? await this.rows('LICH_HEN', 'workScheduleId', key) : [];
    const result = this.updated(collection, key, before, { status: enabled ? 'ACTIVE' : 'INACTIVE', isActive: enabled });
    return { ...result, affectedCount: affected.filter((d) => ['PENDING', 'CONFIRMED'].includes(d.data().status)).length, message: 'Đã cập nhật. Các lịch hẹn đang có được giữ để xử lý riêng.' };
  }
  async schedule(edit) {
    const v = this.input.values || {};
    const doctorId = id(v.doctorId), doctor = await this.get('BAC_SI', doctorId);
    active(doctor, 'Bác sĩ');
    const period = workPeriod(v.workDate, v.startTime, v.endTime);
    future({ workDate: period.day }, v.startTime);
    const duration = number(v.slotDuration, 'Thời lượng ca', 5, 240, true);
    const capacity = number(v.capacity, 'Sức chứa', 1, 100, true);
    const weeks = edit ? 1 : number(v.repeatWeeks ?? 1, 'Số tuần', 1, 8, true);
    const count = Math.ceil((period.end - period.start) / duration);
    if (count * weeks > 240) fail('Tối đa 240 ca mỗi lần.');
    const key = edit ? id(this.input.id) : this.requestId;
    const before = edit ? await this.get('LICH_LAM_VIEC', key) : null;
    if (edit && before.doctorId !== doctorId) fail('Không đổi bác sĩ của lịch đã tạo; hãy tạo lịch mới.');
    const oldSlots = edit ? await this.rows('CA_KHAM', 'workScheduleId', key) : [];
    const appointments = edit ? await this.rows('LICH_HEN', 'workScheduleId', key) : [];
    if (appointments.length || oldSlots.some((s) => s.data().bookedCount !== 0)) fail('Lịch đã có lượt đặt / lịch sử. Hãy ngừng nhận lịch và tạo lịch thay thế.');
    const lastDay = new Date(period.day.getTime() + (weeks - 1) * 7 * 86400000);
    const query = this.db.collection('LICH_LAM_VIEC').where('doctorId', '==', doctorId).where('workDate', '>=', Timestamp.fromDate(period.day)).where('workDate', '<=', Timestamp.fromDate(lastDay));
    const existing = await this.tx.get(query);
    for (let w = 0; w < weeks; w++) {
      const day = new Date(period.day.getTime() + w * 7 * 86400000);
      for (const item of existing.docs) {
        const s = item.data();
        if (item.id !== key && s.status === 'ACTIVE' && dayKey(s.workDate) === dayKey(day) && period.start < minutes(s.endTime) && period.end > minutes(s.startTime)) fail('Lịch làm việc bị trùng giờ với lịch đang hoạt động.');
      }
    }
    const reason = this.reason();
    for (const slot of oldSlots) this.tx.delete(slot.ref);
    for (let w = 0; w < weeks; w++) {
      const scheduleId = w ? `${key}_${w}` : key;
      const fields = { doctorId, workDate: new Date(period.day.getTime() + w * 7 * 86400000), startTime: v.startTime, endTime: v.endTime, slotDuration: duration, capacity, status: 'ACTIVE', updatedAt: stamp() };
      if (edit) this.tx.update(this.ref('LICH_LAM_VIEC', scheduleId), fields);
      else this.tx.create(this.ref('LICH_LAM_VIEC', scheduleId), { ...fields, createdAt: stamp() });
      for (let n = 0; n < count; n++) this.tx.create(this.ref('CA_KHAM', `${this.requestId}_${w}_${n}`), {
        doctorId, workScheduleId: scheduleId, startTime: timeText(period.start + n * duration), endTime: timeText(Math.min(period.end, period.start + (n + 1) * duration)), capacity, bookedCount: 0, status: 'AVAILABLE', createdAt: stamp(), updatedAt: stamp(),
      });
    }
    this.audit('LICH_LAM_VIEC', key, before, { ...v, generatedSlots: count * weeks, reason });
    return { id: key, collection: 'LICH_LAM_VIEC', message: `Đã lưu ${weeks} lịch và ${count * weeks} ca khám.` };
  }
  async slot() {
    const v = this.input.values || {}, key = this.input.id ? id(this.input.id) : this.requestId;
    const before = this.input.id ? await this.get('CA_KHAM', key) : null;
    const scheduleId = before?.workScheduleId || id(v.workScheduleId), schedule = await this.get('LICH_LAM_VIEC', scheduleId);
    active(schedule, 'Lịch làm việc');
    const doctor = await this.get('BAC_SI', schedule.doctorId); active(doctor, 'Bác sĩ');
    const capacity = number(v.capacity, 'Sức chứa', 1, 100, true);
    const start = minutes(v.startTime), end = minutes(v.endTime);
    if (start < minutes(schedule.startTime) || end > minutes(schedule.endTime) || start >= end) fail('Ca phải nằm trong giờ làm việc.');
    future(schedule, v.startTime);
    const related = await this.rows('CA_KHAM', 'workScheduleId', scheduleId);
    const history = before ? await this.rows('LICH_HEN', 'timeSlotId', key) : [];
    if (history.length && (v.startTime !== before.startTime || v.endTime !== before.endTime)) fail('Ca đã có lịch sử, không đổi giờ khám.');
    if (related.some((s) => s.id !== key && start < minutes(s.data().endTime) && end > minutes(s.data().startTime))) fail('Ca khám bị trùng giờ.');
    const booked = before ? number(before.bookedCount, 'Số chỗ', 0, capacity, true) : 0;
    const fields = { workScheduleId: scheduleId, doctorId: schedule.doctorId, startTime: v.startTime, endTime: v.endTime, capacity, bookedCount: booked, status: before?.status === 'UNAVAILABLE' ? 'UNAVAILABLE' : booked >= capacity ? 'BOOKED' : 'AVAILABLE', updatedAt: stamp() };
    this.reason();
    this.tx.update(this.ref('LICH_LAM_VIEC', scheduleId), { adminVersion: FieldValue.increment(1), updatedAt: stamp() });
    if (before) this.tx.update(this.ref('CA_KHAM', key), fields);
    else this.tx.create(this.ref('CA_KHAM', key), { ...fields, createdAt: stamp() });
    this.audit('CA_KHAM', key, before, fields);
    return { id: key, collection: 'CA_KHAM', message: 'Đã lưu ca khám.' };
  }
  async destination(slotId, peopleCount) {
    const slot = await this.get('CA_KHAM', slotId), schedule = await this.get('LICH_LAM_VIEC', slot.workScheduleId);
    const doctor = await this.get('BAC_SI', slot.doctorId), specialty = await this.get('CHUYEN_KHOA', doctor.specialtyId);
    active(schedule, 'Lịch làm việc'); active(doctor, 'Bác sĩ'); active(specialty, 'Chuyên khoa');
    if (slot.status !== 'AVAILABLE' || schedule.doctorId !== slot.doctorId) fail('Ca khám đã đầy, tạm khóa hoặc sai liên kết.');
    if (minutes(slot.startTime) < minutes(schedule.startTime) || minutes(slot.endTime) > minutes(schedule.endTime)) fail('Giờ ca khám không khớp lịch làm việc.');
    future(schedule, slot.startTime);
    return { slot, schedule, doctor, counts: capacityChange(slot, peopleCount) };
  }
  async book() {
    const v = this.input.values || {}, patientId = id(v.patientId), patient = await this.get('BENH_NHAN', patientId);
    if (patient.isActive === false || patient.status === 'ARCHIVED') fail('Hồ sơ bệnh nhân đang được lưu trữ.');
    const peopleCount = number(v.peopleCount ?? 1, 'Số người', 1, 100, true);
    const slotId = id(v.timeSlotId), target = await this.destination(slotId, peopleCount);
    const key = this.requestId;
    const fields = { patientId, doctorId: target.slot.doctorId, workScheduleId: target.slot.workScheduleId, timeSlotId: slotId, specialtyId: target.doctor.specialtyId, appointmentDate: target.schedule.workDate, startTime: target.slot.startTime, endTime: target.slot.endTime, status: 'PENDING', peopleCount, reason: text(v.reason, 'Lý do khám', 1000, false), symptoms: text(v.reason, 'Lý do khám', 1000, false), consultationFeeSnapshot: target.doctor.consultationFee, bookedAt: stamp(), createdAt: stamp(), updatedAt: stamp() };
    this.reason();
    this.tx.create(this.ref('LICH_HEN', key), fields);
    this.tx.update(this.ref('CA_KHAM', slotId), { ...target.counts, appointmentId: key, updatedAt: stamp() });
    this.notification('book', patient, patientId, 'Đã tiếp nhận lịch khám', `Mã lịch ${key}. Lịch đang chờ xác nhận.`, key);
    this.audit('LICH_HEN', key, null, fields);
    return { id: key, collection: 'LICH_HEN', message: 'Đã tạo lịch hẹn và giữ chỗ.' };
  }
  async appointmentStatus() {
    const key = id(this.input.id), before = await this.get('LICH_HEN', key);
    const next = choice(this.input.values?.status, ['CONFIRMED', 'CANCELLED', 'NO_SHOW']);
    transition(before.status, next); this.reason();
    if (next === 'NO_SHOW' && bookingTime(before.appointmentDate, before.endTime || before.startTime) > new Date()) fail('Chỉ đánh dấu vắng mặt sau khi hết giờ khám.');
    const patient = await this.get('BENH_NHAN', before.patientId);
    const slot = next === 'CANCELLED' ? await this.get('CA_KHAM', before.timeSlotId) : null;
    const others = slot ? await this.rows('LICH_HEN', 'timeSlotId', before.timeSlotId) : [];
    const fields = { status: next, ...(next === 'CANCELLED' ? { cancellationReason: this.input.reason } : {}) };
    if (slot) {
      const pointer = others.find((d) => d.id !== key && heldStatuses.has(d.data().status));
      this.tx.update(this.ref('CA_KHAM', before.timeSlotId), { ...capacityChange(slot, -number(before.peopleCount ?? 1, 'Số người', 1, 100, true)), appointmentId: pointer?.id || FieldValue.delete(), updatedAt: stamp() });
    }
    this.notification('status', patient, before.patientId, next === 'CANCELLED' ? 'Lịch khám đã được hủy' : next === 'CONFIRMED' ? 'Lịch khám đã được xác nhận' : 'Ghi nhận vắng mặt', `Mã lịch ${key}. ${this.input.reason}`, key);
    return this.updated('LICH_HEN', key, before, fields);
  }
  async reschedule() {
    const key = id(this.input.id), before = await this.get('LICH_HEN', key);
    if (!['PENDING', 'CONFIRMED'].includes(before.status)) fail('Chỉ đổi lịch chưa kết thúc.');
    const slotId = id(this.input.values?.timeSlotId);
    if (slotId === before.timeSlotId) fail('Hãy chọn ca khác.');
    const oldSlot = await this.get('CA_KHAM', before.timeSlotId);
    const count = number(before.peopleCount ?? 1, 'Số người', 1, 100, true);
    const target = await this.destination(slotId, count);
    const patient = await this.get('BENH_NHAN', before.patientId);
    const others = await this.rows('LICH_HEN', 'timeSlotId', before.timeSlotId);
    this.reason();
    const pointer = others.find((d) => d.id !== key && heldStatuses.has(d.data().status));
    this.tx.update(this.ref('CA_KHAM', before.timeSlotId), { ...capacityChange(oldSlot, -count), appointmentId: pointer?.id || FieldValue.delete(), updatedAt: stamp() });
    this.tx.update(this.ref('CA_KHAM', slotId), { ...target.counts, appointmentId: key, updatedAt: stamp() });
    const fields = { doctorId: target.slot.doctorId, workScheduleId: target.slot.workScheduleId, timeSlotId: slotId, specialtyId: target.doctor.specialtyId, appointmentDate: target.schedule.workDate, startTime: target.slot.startTime, endTime: target.slot.endTime, rescheduleReason: this.input.reason };
    this.notification('reschedule', patient, before.patientId, 'Lịch khám đã thay đổi', `Mã lịch ${key}. Ngày ${dayKey(target.schedule.workDate)}, ${target.slot.startTime}. ${this.input.reason}`, key);
    return this.updated('LICH_HEN', key, before, fields);
  }
  async internalNote() {
    const key = id(this.input.id), before = await this.get('LICH_HEN', key);
    const note = text(this.input.values?.internalNote, 'Ghi chú nội bộ', 2000, false);
    // Separate collection: patient/doctor access to appointments must not leak internal notes.
    this.tx.set(this.ref('ADMIN_NOTES', key), { appointmentId: key, internalNote: note, actorId: this.uid, updatedAt: stamp() });
    this.audit('ADMIN_NOTES', key, null, { internalNote: note });
    return { id: key, collection: 'ADMIN_NOTES', message: 'Đã lưu ghi chú nội bộ, chỉ admin xem được.' };
  }
  async accountAccess() {
    const key = id(this.input.id), before = await this.get('TAI_KHOAN', key), v = this.input.values || {};
    this.reason();
    if (key === this.uid) fail('Không tự khóa hoặc đổi quyền tài khoản đang đăng nhập.');
    const role = choice(v.role ?? before.role, ['patient', 'doctor', 'admin'], 'Vai trò');
    const doctors = await this.rows('BAC_SI', 'userId', key, 2);
    const patients = await this.rows('BENH_NHAN', 'authUserId', key);
    if (role === 'doctor' && doctors.length !== 1) fail('Tài khoản bác sĩ phải có đúng một hồ sơ bác sĩ liên kết.');
    if (role !== before.role && (doctors.length || patients.length)) fail('Không đổi vai trò tài khoản đã liên kết hồ sơ. Hãy tạo tài khoản nhân sự phù hợp.');
    if (typeof v.isActive !== 'boolean') fail('Thiếu trạng thái tài khoản.', 'invalid-argument');
    return this.updated('TAI_KHOAN', key, before, { role, isActive: v.isActive, status: v.isActive ? 'ACTIVE' : 'INACTIVE' });
  }
  async feedback() {
    const key = id(this.input.id), before = await this.get('PHAN_HOI', key), v = this.input.values || {};
    const assigneeId = id(v.assigneeId || this.uid);
    const assignee = await this.get('TAI_KHOAN', assigneeId);
    if (assignee.role !== 'admin' || !assignee.isActive) fail('Người xử lý phải là admin đang hoạt động.');
    const fields = { processingStatus: choice(v.processingStatus, ['NEW', 'PROCESSING', 'RESOLVED']), assigneeId, response: text(v.response, 'Trả lời', 2000, false) };
    const patient = before.patientId ? await this.get('BENH_NHAN', before.patientId) : null;
    this.reason();
    if (patient && fields.response) this.notification('feedback', patient, before.patientId, 'Phản hồi từ HealWay', fields.response);
    return this.updated('PHAN_HOI', key, before, fields);
  }
  async passwordSetup() {
    const key = id(this.input.id), account = await this.get('TAI_KHOAN', key);
    if (account.role !== 'doctor' || account.isActive !== true) fail('Chỉ gửi cho tài khoản bác sĩ đang hoạt động.');
    const user = await this.auth.getUser(key);
    if (user.disabled || !user.email || user.email.toLowerCase() !== account.email?.toLowerCase()) fail('Email đăng nhập chưa khớp tài khoản xác thực.');
    this.reason();
    this.audit('TAI_KHOAN', key, null, { email: user.email, event: 'PASSWORD_SETUP_REQUESTED' });
    return { id: key, collection: 'TAI_KHOAN', loginEmail: user.email, message: 'Đã xác minh người nhận.' };
  }
  async notificationDraft() {
    const v = this.input.values || {}, key = this.input.id ? id(this.input.id) : this.requestId;
    const before = this.input.id ? await this.get('THONG_BAO', key) : null;
    if (before && before.status !== 'DRAFT') fail('Thông báo đã gửi không được sửa.');
    const patientId = id(v.patientId); await this.get('BENH_NHAN', patientId);
    const fields = { title: text(v.title, 'Tiêu đề', 160), content: text(v.content, 'Nội dung', 4000), patientId, status: 'DRAFT', isRead: false, updatedAt: stamp() };
    if (before) return this.updated('THONG_BAO', key, before, fields);
    this.tx.create(this.ref('THONG_BAO', key), { ...fields, createdAt: stamp(), createdBy: this.uid });
    this.audit('THONG_BAO', key, null, fields);
    return { id: key, collection: 'THONG_BAO', message: 'Đã lưu bản nháp, chưa gửi.' };
  }
  async sendNotification() {
    const key = id(this.input.id), before = await this.get('THONG_BAO', key);
    if (before.status !== 'DRAFT') fail('Chỉ gửi bản nháp; thông báo này đã gửi hoặc thiếu trạng thái.');
    const patient = await this.get('BENH_NHAN', before.patientId); this.reason();
    return this.updated('THONG_BAO', key, before, { status: 'SENT', channel: 'in_app', userId: patient.authUserId, sentAt: stamp() });
  }
  async paymentReview() {
    const key = id(this.input.id), before = await this.get('THANH_TOAN', key), v = this.input.values || {};
    this.reason();
    if (v.refundRequested === true) {
      if (!['PAID', 'SUCCESS'].includes(before.status)) fail('Chỉ yêu cầu hoàn tiền cho giao dịch thành công.');
      if (before.refundRequestId) fail('Giao dịch đã có yêu cầu hoàn tiền.');
      const fields = { paymentId: key, amount: before.amount, status: 'REQUESTED', reason: this.input.reason, createdAt: stamp(), actorId: this.uid };
      this.tx.create(this.ref('YEU_CAU_HOAN_TIEN', this.requestId), fields);
      return this.updated('THANH_TOAN', key, before, { refundRequestId: this.requestId, refundStatus: 'REQUESTED' });
    }
    return this.updated('THANH_TOAN', key, before, { reviewStatus: choice(v.reviewStatus, ['UNREVIEWED', 'REVIEWED', 'NEEDS_CHECK']), reviewNote: text(v.reviewNote, 'Ghi chú đối soát', 2000, false) });
  }
  async settings() {
    const v = this.input.values || {}, ref = this.ref('CAU_HINH', 'general'), previous = await this.tx.get(ref);
    const fields = { hospitalName: text(v.hospitalName, 'Tên cơ sở', 160), supportPhone: text(v.supportPhone, 'Điện thoại', 30), supportEmail: email(v.supportEmail), address: text(v.address, 'Địa chỉ', 300, false), defaultSlotDuration: number(v.defaultSlotDuration, 'Thời lượng ca mặc định', 5, 240, true), defaultCapacity: number(v.defaultCapacity, 'Sức chứa mặc định', 1, 100, true), updatedAt: stamp() };
    this.reason();
    this.tx.set(ref, fields); this.audit('CAU_HINH', 'general', previous.exists ? previous.data() : null, fields);
    return { id: 'general', collection: 'CAU_HINH', message: 'Đã lưu thông tin quản trị và giá trị mặc định tạo lịch.' };
  }
}

/** Auth is a separate service. Persist a recoverable provisioning record first. */
async function provisionDoctor(db, auth, uid, input) {
  const values = { ...input.values }, loginEmail = email(values.loginEmail);
  delete values.loginEmail;
  const fields = cleanFields('BAC_SI', values, true);
  text(input.reason, 'Lý do', 500);
  const key = id(input.requestId), receipt = db.collection('ADMIN_COMMANDS').doc(`${uid}_${key}`), ref = db.collection('ADMIN_PROVISIONING').doc(key);
  const fingerprint = digest(input);
  const cached = await receipt.get();
  if (cached.exists) {
    if (cached.data().fingerprint !== fingerprint) fail('Yêu cầu trùng nhưng nội dung khác.', 'already-exists');
    return cached.data().result;
  }
  await db.runTransaction(async (tx) => {
    const currentActor = snapshotData(await tx.get(db.collection('TAI_KHOAN').doc(uid)));
    if (currentActor.role !== 'admin' || !currentActor.isActive) fail('Không có quyền.', 'permission-denied');
    active(snapshotData(await tx.get(db.collection('CHUYEN_KHOA').doc(fields.specialtyId))), 'Chuyên khoa');
    const existing = await tx.get(ref);
    if (existing.exists) {
      if (existing.data().status !== 'FAILED' || existing.data().fingerprint !== fingerprint || existing.data().actorId !== uid) fail('Yêu cầu đang xử lý hoặc cần kiểm tra mục cấp tài khoản. Không gửi lại bằng yêu cầu mới.');
      tx.update(ref, { status: 'CREATING', updatedAt: stamp() });
    } else tx.create(ref, { actorId: uid, fingerprint, loginEmail, status: 'CREATING', createdAt: stamp() });
  });
  let user;
  try {
    user = await auth.createUser({ email: loginEmail, displayName: fields.fullName, password: randomBytes(32).toString('base64url'), disabled: false });
    await ref.update({ authUserId: user.uid, status: 'AUTH_CREATED', updatedAt: stamp() });
    const result = { id: user.uid, collection: 'BAC_SI', loginEmail, message: 'Đã tạo hồ sơ và tài khoản bác sĩ. Cần gửi email thiết lập mật khẩu.' };
    await db.runTransaction(async (tx) => {
      const actor = snapshotData(await tx.get(db.collection('TAI_KHOAN').doc(uid)));
      if (actor.role !== 'admin' || !actor.isActive) fail('Quyền admin đã thay đổi.', 'permission-denied');
      active(snapshotData(await tx.get(db.collection('CHUYEN_KHOA').doc(fields.specialtyId))), 'Chuyên khoa');
      tx.create(db.collection('TAI_KHOAN').doc(user.uid), { email: loginEmail, fullName: fields.fullName, phone: fields.phone || '', role: 'doctor', isActive: true, createdAt: stamp(), updatedAt: stamp() });
      tx.create(db.collection('BAC_SI').doc(user.uid), { ...fields, userId: user.uid, acceptingBookings: true, status: 'ACTIVE', isActive: true, createdAt: stamp(), updatedAt: stamp() });
      tx.create(db.collection('NHAT_KY_ADMIN').doc(key), { actorId: uid, action: 'createDoctor', targetCollection: 'BAC_SI', targetId: user.uid, reason: input.reason, before: null, after: { ...fields, loginEmail }, createdAt: stamp() });
      tx.create(receipt, { fingerprint, result, createdAt: stamp() });
      tx.update(ref, { status: 'READY', authUserId: user.uid, updatedAt: stamp() });
    });
    return result;
  } catch (error) {
    // An acknowledgement may be lost after a successful commit. Never delete
    // the Auth user until the durable receipt has been checked successfully.
    try {
      const completed = await receipt.get();
      if (completed.exists && completed.data().fingerprint === fingerprint) return completed.data().result;
    } catch {
      try { await ref.set({ status: 'NEEDS_RECOVERY', ...(user ? { authUserId: user.uid } : {}), updatedAt: stamp() }, { merge: true }); } catch { /* original provisioning record survives */ }
      fail('Chưa xác minh được kết quả cấp tài khoản. Cần kiểm tra ADMIN_PROVISIONING trước khi tạo lại.');
    }
    let cleaned = !user;
    if (user) {
      try { await auth.deleteUser(user.uid); cleaned = true; } catch { /* recoverable ID retained below */ }
    }
    await ref.set({ status: cleaned ? 'FAILED' : 'NEEDS_RECOVERY', ...(user ? { authUserId: user.uid } : {}), failureCode: error.code || 'unknown', updatedAt: stamp() }, { merge: true });
    if (!cleaned) fail('Chưa tạo xong hồ sơ; tài khoản cần quản trị hệ thống khôi phục tại ADMIN_PROVISIONING. Không tạo lại.');
    if (error.code === 'auth/email-already-exists') fail('Email đăng nhập đã được sử dụng.', 'already-exists');
    if (error instanceof AdminError) throw error;
    fail('Không thể hoàn tất cấp tài khoản. Tài khoản mới đã được thu hồi; kiểm tra cấu hình rồi thử yêu cầu mới.');
  }
}
