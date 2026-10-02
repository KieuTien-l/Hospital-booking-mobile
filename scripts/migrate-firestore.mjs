import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
const cleanup = process.argv.slice(2).includes('--cleanup');
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;

if (!serviceAccountPath) {
  throw new Error(
    'Set FIREBASE_SERVICE_ACCOUNT_PATH to a Firebase service-account JSON file.',
  );
}

const serviceAccount = JSON.parse(
  await readFile(resolve(serviceAccountPath), 'utf8'),
);
if (serviceAccount.project_id !== projectId) {
  throw new Error(
    `The service account is for ${serviceAccount.project_id}, not ${projectId}.`,
  );
}

if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount), projectId });
}

const firestore = getFirestore();
const collectionMappers = new Map([
  ['TAI_KHOAN', mapAccount],
  ['BENH_NHAN', mapPatient],
  ['CHUYEN_KHOA', mapSpecialty],
  ['BAC_SI', mapDoctor],
  ['LICH_LAM_VIEC', mapWorkSchedule],
  ['CA_KHAM', mapTimeSlot],
  ['LICH_HEN', mapAppointment],
  ['LS_CHAT_AI', mapChatMessage],
  ['THANH_TOAN', mapPayment],
  ['THONG_BAO', mapNotification],
]);

const legacyFieldMappings = new Map([
  [
    'TAI_KHOAN',
    [
      legacy('Email', 'email'),
      legacy('HoTen', 'fullName'),
      legacy('SoDienThoai', 'phone'),
      legacy('Quyen', 'role'),
      legacy('TrangThai', 'isActive'),
      legacy('Khoa', 'department'),
      legacy('MaTK', 'accountKey'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'BENH_NHAN',
    [
      legacy('MaTK', 'authUserId'),
      legacy('HoTen', 'fullName'),
      legacy('SoDienThoai', 'phone'),
      legacy('Email', 'email'),
      legacy('NgaySinh', 'dateOfBirth'),
      legacy('GioiTinh', 'gender'),
      legacy('SoNha', 'address'),
      legacy('DiaChi', 'address'),
      legacy('AnhDaiDien', 'avatarUrl'),
      legacy('MaBHYT', 'insuranceNumber'),
      legacy('DanToc', 'ethnicity'),
      legacy('NgheNghiep', 'occupation'),
      legacy('PhuongXa', 'ward'),
      legacy('QuanHuyen', 'district'),
      legacy('TinhThanh', 'province'),
      legacy('QuocGia', 'country'),
      legacy('SoCCCD', 'nationalId'),
      legacy('QuanHeChuTaiKhoan', 'relationshipToAccountHolder'),
      legacy('TrangThai', 'status', 'isActive'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'CHUYEN_KHOA',
    [
      legacy('TenChuyenKhoa', 'name'),
      legacy('MoTa', 'description'),
      legacy('HinhAnh', 'imageUrl'),
      legacy('TrangThai', 'status', 'isActive'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'BAC_SI',
    [
      legacy('MaTK', 'userId'),
      legacy('HoTen', 'fullName'),
      legacy('Email', 'email'),
      legacy('SoDienThoai', 'phone'),
      legacy('MaCK', 'specialtyId'),
      legacy('KinhNghiem', 'yearsOfExperience'),
      legacy('GiaKham', 'consultationFee'),
      legacy('TrangThai', 'status', 'isActive'),
      legacy('TenChuyenKhoa', 'specialtyName'),
      legacy('HocHamHocVi', 'qualification'),
      legacy('MoTaChiTiet', 'biography'),
      legacy('AnhDaiDien', 'avatarUrl'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'LICH_LAM_VIEC',
    [
      legacy('MaBS', 'doctorId'),
      legacy('NgayLamViec', 'workDate'),
      legacy('GioBatDau', 'startTime'),
      legacy('GioKetThuc', 'endTime'),
      legacy('TrangThai', 'status'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'CA_KHAM',
    [
      legacy('MaLLV', 'workScheduleId'),
      legacy('MaBS', 'doctorId'),
      legacy('GioBatDau', 'startTime'),
      legacy('GioKetThuc', 'endTime'),
      legacy('SoLuongDaDat', 'bookedCount'),
      legacy('SoLuongToiDa', 'capacity'),
      legacy('MaLichHen', 'appointmentId'),
      legacy('TrangThai', 'status'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'LICH_HEN',
    [
      legacy('MyBN', 'patientId'),
      legacy('MaBN', 'patientId'),
      legacy('MaBS', 'doctorId'),
      legacy('MaLLV', 'workScheduleId'),
      legacy('Maca', 'timeSlotId'),
      legacy('MaCa', 'timeSlotId'),
      legacy('MaCK', 'specialtyId'),
      legacy('NgayKham', 'appointmentDate'),
      legacy('NgayHen', 'appointmentDate'),
      legacy('GioBatDau', 'startTime'),
      legacy('GioKetThuc', 'endTime'),
      legacy('NgayDat', 'bookedAt'),
      legacy('TrangThai', 'status'),
      legacy('LyDoKham', 'reason'),
      legacy('GhiChu', 'note'),
      legacy('LyDoHuy', 'cancellationReason'),
      legacy('TrieuChung', 'symptoms'),
      legacy('SoNguoiKham', 'peopleCount'),
      legacy('SoThuTuKham', 'queueNumber'),
      legacy('ThoiGianCheckIn', 'checkInTime'),
      legacy('MaQR', 'qrCode'),
      legacy('QR Code', 'qrCode'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'LS_CHAT_AI',
    [
      legacy('PhanHoiAI', 'aiReply'),
      legacy('MaPhien', 'sessionId'),
      legacy('ThoiGian', 'timestamp'),
      legacy('MaTK', 'userId'),
      legacy('MaBN', 'userId'),
      legacy('TinNhanNguoiDung', 'userMessage'),
      legacy('NgayTao', 'createdAt'),
      legacy('NgayCapNhat', 'updatedAt'),
    ],
  ],
  [
    'THANH_TOAN',
    [
      legacy('MaGiaoDich', 'transactionCode'),
      legacy('MaLH', 'appointmentId'),
      legacy('NgayTao', 'createdAt'),
      legacy('PhuongThuc', 'paymentMethod'),
      legacy('SoTien', 'amount'),
      legacy('ThoiGianThanhToan', 'paidAt'),
      legacy('TrangThai', 'status'),
    ],
  ],
  [
    'THONG_BAO',
    [
      legacy('DaDoc', 'isRead'),
      legacy('LoaiThongBao', 'notificationType'),
      legacy('MaLH', 'appointmentId'),
      legacy('MaTK', 'accountId'),
      legacy('NgayTao', 'createdAt'),
      legacy('NoiDung', 'content'),
      legacy('TieuDe', 'title'),
    ],
  ],
]);

const summary = [];
if (cleanup) {
  for (const [collectionName, mappings] of legacyFieldMappings) {
    summary.push(await cleanLegacyFields(collectionName, mappings));
  }
} else {
  for (const [collectionName, mapper] of collectionMappers) {
    const snapshot = await firestore.collection(collectionName).get();
    const pendingUpdates = [];
    let fieldsToAdd = 0;

    for (const document of snapshot.docs) {
      const changes = mapper(document.data());
      const changeCount = Object.keys(changes).length;
      if (changeCount === 0) continue;
      fieldsToAdd += changeCount;
      pendingUpdates.push({ reference: document.ref, changes });
    }

    if (apply) {
      await commitInBatches(pendingUpdates);
    }

    summary.push({
      collection: collectionName,
      scanned: snapshot.size,
      documentsToUpdate: pendingUpdates.length,
      fieldsToAdd,
    });
  }

  // A collection created manually with a leading space is a different Firestore
  // collection. Copy its specialty documents into the canonical collection rather
  // than attempting a rename (Firestore has no rename operation). The originals
  // remain untouched as a recovery source.
  summary.push(await migrateLeadingSpaceSpecialties());
}

console.table(summary);
console.log(
  cleanup
    ? apply
      ? 'Cleanup completed. Only legacy fields with a populated canonical replacement were deleted.'
      : 'Cleanup dry run completed. No Firestore document was changed. Run again with --cleanup --apply to delete the fields shown above.'
    : apply
      ? 'Migration completed. Legacy fields and document IDs were preserved.'
      : 'Dry run completed. No Firestore document was changed. Run again with --apply to add the fields shown above.',
);

async function commitInBatches(updates) {
  const batchSize = 400;
  for (let start = 0; start < updates.length; start += batchSize) {
    const batch = firestore.batch();
    for (const { reference, changes } of updates.slice(start, start + batchSize)) {
      batch.update(reference, changes);
    }
    await batch.commit();
  }
}

async function cleanLegacyFields(collectionName, mappings) {
  const snapshot = await firestore.collection(collectionName).get();
  const pendingUpdates = [];
  let fieldsToDelete = 0;

  for (const document of snapshot.docs) {
    const data = document.data();
    const changes = {};

    for (const { source, targets } of mappings) {
      if (!Object.hasOwn(data, source)) continue;
      if (
        data[source] == null ||
        targets.every((target) => hasCanonicalValue(data[target]))
      ) {
        changes[source] = FieldValue.delete();
      }
    }

    const changeCount = Object.keys(changes).length;
    if (changeCount === 0) continue;
    fieldsToDelete += changeCount;
    pendingUpdates.push({ reference: document.ref, changes });
  }

  if (apply) {
    await commitInBatches(pendingUpdates);
  }

  return {
    collection: collectionName,
    scanned: snapshot.size,
    documentsToClean: pendingUpdates.length,
    fieldsToDelete,
  };
}

function legacy(source, ...targets) {
  return { source, targets };
}

function hasCanonicalValue(value) {
  if (value == null) return false;
  return typeof value !== 'string' || value.trim().length > 0;
}

async function migrateLeadingSpaceSpecialties() {
  const sourceCollection = ' CHUYEN_KHOA';
  const destinationCollection = 'CHUYEN_KHOA';
  const sourceSnapshot = await firestore.collection(sourceCollection).get();
  const pendingCreates = [];
  let fieldsToAdd = 0;

  for (const sourceDocument of sourceSnapshot.docs) {
    const destinationReference = firestore
      .collection(destinationCollection)
      .doc(sourceDocument.id);
    const destinationDocument = await destinationReference.get();
    const mappedFields = mapSpecialty(sourceDocument.data());
    const destinationData = destinationDocument.exists
      ? destinationDocument.data()
      : {};
    const changes = Object.fromEntries(
      Object.entries(mappedFields).filter(
        ([fieldName]) => !Object.hasOwn(destinationData, fieldName),
      ),
    );

    if (!destinationDocument.exists && Object.keys(changes).length > 0) {
      fieldsToAdd += Object.keys(changes).length;
      pendingCreates.push({ reference: destinationReference, changes });
    }
  }

  if (apply) {
    await createInBatches(pendingCreates);
  }

  return {
    collection: `${sourceCollection} -> ${destinationCollection}`,
    scanned: sourceSnapshot.size,
    documentsToCreate: pendingCreates.length,
    fieldsToAdd,
  };
}

async function createInBatches(documents) {
  const batchSize = 400;
  for (let start = 0; start < documents.length; start += batchSize) {
    const batch = firestore.batch();
    for (const { reference, changes } of documents.slice(start, start + batchSize)) {
      batch.create(reference, changes);
    }
    await batch.commit();
  }
}

function mapAccount(data) {
  const changes = {};
  copy(data, changes, 'department', ['Khoa']);
  copy(data, changes, 'accountKey', ['MaTK'], referenceId);
  copy(data, changes, 'email', ['Email']);
  copy(data, changes, 'fullName', ['HoTen']);
  copy(data, changes, 'phone', ['SoDienThoai']);
  copy(data, changes, 'role', ['Quyen'], roleValue);
  copy(data, changes, 'isActive', ['TrangThai'], isActive);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapPatient(data) {
  const changes = {};
  copy(data, changes, 'authUserId', ['MaTK'], referenceId);
  copy(data, changes, 'fullName', ['HoTen']);
  copy(data, changes, 'phone', ['SoDienThoai']);
  copy(data, changes, 'email', ['Email']);
  copy(data, changes, 'dateOfBirth', ['NgaySinh']);
  copy(data, changes, 'gender', ['GioiTinh']);
  copy(data, changes, 'address', ['SoNha', 'DiaChi']);
  copy(data, changes, 'avatarUrl', ['AnhDaiDien']);
  copy(data, changes, 'insuranceNumber', ['MaBHYT']);
  copy(data, changes, 'ethnicity', ['DanToc']);
  copy(data, changes, 'occupation', ['NgheNghiep']);
  copy(data, changes, 'ward', ['PhuongXa']);
  copy(data, changes, 'district', ['QuanHuyen']);
  copy(data, changes, 'province', ['TinhThanh']);
  copy(data, changes, 'country', ['QuocGia']);
  copy(data, changes, 'nationalId', ['SoCCCD']);
  copy(data, changes, 'relationshipToAccountHolder', ['QuanHeChuTaiKhoan']);
  copy(data, changes, 'status', ['TrangThai'], activityStatus);
  copy(data, changes, 'isActive', ['TrangThai'], isActive);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapSpecialty(data) {
  const changes = {};
  copy(data, changes, 'name', ['TenChuyenKhoa']);
  copy(data, changes, 'description', ['MoTa']);
  copy(data, changes, 'imageUrl', ['HinhAnh']);
  copy(data, changes, 'status', ['TrangThai'], activityStatus);
  copy(data, changes, 'isActive', ['TrangThai'], isActive);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapDoctor(data) {
  const changes = {};
  copy(data, changes, 'userId', ['MaTK'], referenceId);
  copy(data, changes, 'fullName', ['HoTen']);
  copy(data, changes, 'email', ['Email']);
  copy(data, changes, 'phone', ['SoDienThoai']);
  copy(data, changes, 'specialtyId', ['MaCK'], referenceId);
  copy(data, changes, 'yearsOfExperience', ['KinhNghiem']);
  copy(data, changes, 'consultationFee', ['GiaKham']);
  copy(data, changes, 'status', ['TrangThai'], activityStatus);
  copy(data, changes, 'isActive', ['TrangThai'], isActive);
  copy(data, changes, 'specialtyName', ['TenChuyenKhoa']);
  copy(data, changes, 'qualification', ['HocHamHocVi']);
  copy(data, changes, 'biography', ['MoTaChiTiet']);
  copy(data, changes, 'avatarUrl', ['AnhDaiDien']);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapWorkSchedule(data) {
  const changes = {};
  copy(data, changes, 'doctorId', ['MaBS'], referenceId);
  copy(data, changes, 'workDate', ['NgayLamViec']);
  copy(data, changes, 'startTime', ['GioBatDau']);
  copy(data, changes, 'endTime', ['GioKetThuc']);
  copy(data, changes, 'status', ['TrangThai'], activityStatus);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapTimeSlot(data) {
  const changes = {};
  copy(data, changes, 'workScheduleId', ['MaLLV'], referenceId);
  copy(data, changes, 'doctorId', ['MaBS'], referenceId);
  copy(data, changes, 'startTime', ['GioBatDau']);
  copy(data, changes, 'endTime', ['GioKetThuc']);
  copy(data, changes, 'bookedCount', ['SoLuongDaDat']);
  copy(data, changes, 'capacity', ['SoLuongToiDa']);
  copy(data, changes, 'appointmentId', ['MaLichHen'], referenceId);
  copy(data, changes, 'status', ['TrangThai'], timeSlotStatus);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapAppointment(data) {
  const changes = {};
  copy(data, changes, 'patientId', ['MyBN', 'MaBN'], referenceId);
  copy(data, changes, 'doctorId', ['MaBS'], referenceId);
  copy(data, changes, 'workScheduleId', ['MaLLV'], referenceId);
  copy(data, changes, 'timeSlotId', ['Maca', 'MaCa'], referenceId);
  copy(data, changes, 'specialtyId', ['MaCK'], referenceId);
  copy(data, changes, 'appointmentDate', ['NgayKham', 'NgayHen']);
  copy(data, changes, 'startTime', ['GioBatDau']);
  copy(data, changes, 'endTime', ['GioKetThuc']);
  copy(data, changes, 'bookedAt', ['NgayDat']);
  copy(data, changes, 'status', ['TrangThai'], appointmentStatus);
  copy(data, changes, 'reason', ['LyDoKham']);
  copy(data, changes, 'note', ['GhiChu']);
  copy(data, changes, 'cancellationReason', ['LyDoHuy']);
  copy(data, changes, 'symptoms', ['TrieuChung']);
  copy(data, changes, 'peopleCount', ['SoNguoiKham']);
  copy(data, changes, 'queueNumber', ['SoThuTuKham']);
  copy(data, changes, 'checkInTime', ['ThoiGianCheckIn']);
  copy(data, changes, 'qrCode', ['MaQR', 'QR Code']);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapChatMessage(data) {
  const changes = {};
  copy(data, changes, 'aiReply', ['PhanHoiAI']);
  copy(data, changes, 'sessionId', ['MaPhien']);
  copy(data, changes, 'timestamp', ['ThoiGian']);
  copy(data, changes, 'userId', ['MaTK', 'MaBN'], referenceId);
  copy(data, changes, 'userMessage', ['TinNhanNguoiDung']);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'updatedAt', ['NgayCapNhat']);
  return changes;
}

function mapPayment(data) {
  const changes = {};
  copy(data, changes, 'transactionCode', ['MaGiaoDich']);
  copy(data, changes, 'appointmentId', ['MaLH'], referenceId);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'paymentMethod', ['PhuongThuc']);
  copy(data, changes, 'amount', ['SoTien']);
  copy(data, changes, 'paidAt', ['ThoiGianThanhToan']);
  copy(data, changes, 'status', ['TrangThai']);
  return changes;
}

function mapNotification(data) {
  const changes = {};
  copy(data, changes, 'isRead', ['DaDoc']);
  copy(data, changes, 'notificationType', ['LoaiThongBao']);
  copy(data, changes, 'appointmentId', ['MaLH'], referenceId);
  copy(data, changes, 'accountId', ['MaTK'], referenceId);
  copy(data, changes, 'createdAt', ['NgayTao']);
  copy(data, changes, 'content', ['NoiDung']);
  copy(data, changes, 'title', ['TieuDe']);
  return changes;
}

function copy(data, changes, target, sources, transform = (value) => value) {
  if (Object.hasOwn(data, target)) return;
  for (const source of sources) {
    if (!Object.hasOwn(data, source) || data[source] == null) continue;
    const value = transform(data[source]);
    if (value !== '') changes[target] = value;
    return;
  }
}

function referenceId(value) {
  if (
    value &&
    typeof value === 'object' &&
    typeof value.id === 'string' &&
    typeof value.path === 'string'
  ) {
    return value.id;
  }
  return String(value).trim();
}

function isActive(value) {
  return !['INACTIVE', 'DISABLED', 'FALSE', '0'].includes(
    String(value).trim().toUpperCase(),
  );
}

function activityStatus(value) {
  return isActive(value) ? 'ACTIVE' : 'INACTIVE';
}

function roleValue(value) {
  switch (String(value).trim().toLowerCase()) {
    case 'doctor':
    case 'bac_si':
    case 'bác sĩ':
      return 'doctor';
    case 'admin':
    case 'administrator':
    case 'quan_tri_vien':
    case 'quản trị viên':
      return 'admin';
    default:
      return 'patient';
  }
}

function timeSlotStatus(value) {
  switch (String(value).trim().toUpperCase()) {
    case 'AVAILABLE':
    case 'AVAILABLE_SLOT':
    case 'TRONG':
      return 'AVAILABLE';
    case 'BOOKED':
    case 'DA_DAT':
    case 'DADAT':
      return 'BOOKED';
    case 'UNAVAILABLE':
    case 'BLOCKED':
      return 'UNAVAILABLE';
    case 'CANCELLED':
    case 'CANCELED':
      return 'CANCELLED';
    default:
      return 'UNAVAILABLE';
  }
}

function appointmentStatus(value) {
  switch (String(value).trim().toUpperCase()) {
    case 'PENDING':
    case 'CHO_XAC_NHAN':
      return 'PENDING';
    case 'CONFIRMED':
    case 'DA_XAC_NHAN':
      return 'CONFIRMED';
    case 'COMPLETED':
    case 'HOAN_THANH':
      return 'COMPLETED';
    case 'CANCELLED':
    case 'CANCELED':
    case 'DA_HUY':
      return 'CANCELLED';
    case 'NO_SHOW':
      return 'NO_SHOW';
    default:
      return 'PENDING';
  }
}
