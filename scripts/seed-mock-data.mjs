import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const projectId = 'bookinghospitalapp';
const apply = process.argv.slice(2).includes('--apply');
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

async function seedMockData() {
  console.log('🚀 Đang chuẩn bị dữ liệu mẫu (Mock Data)...');
  
  const now = Timestamp.now();
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowTimestamp = Timestamp.fromDate(tomorrow);

  // --- 1. CHUYEN_KHOA ---
  const specialties = [
    { id: 'mock_ck_1', name: 'Khoa Tim Mạch', description: 'Khám và điều trị các bệnh lý tim mạch.', isActive: true, imageUrl: 'https://example.com/tim-mach.jpg' },
    { id: 'mock_ck_2', name: 'Khoa Thần Kinh', description: 'Điều trị các bệnh lý về não và thần kinh.', isActive: true, imageUrl: 'https://example.com/than-kinh.jpg' },
    { id: 'mock_ck_3', name: 'Khoa Da Liễu', description: 'Chăm sóc và điều trị các bệnh ngoài da.', isActive: true, imageUrl: 'https://example.com/da-lieu.jpg' }
  ];

  // --- 2. BAC_SI ---
  const doctors = [
    { 
      id: 'mock_bs_1', 
      userId: '44', 
      fullName: 'Trần Quốc Bảo', 
      email: 'baotq@mock.com', 
      phone: '0901111111', 
      specialtyId: 'mock_ck_1', 
      specialtyName: 'Khoa Khám bệnh', 
      yearsOfExperience: 7, 
      consultationFee: 180000, 
      isActive: true, 
      status: 'ACTIVE', 
      qualification: 'Thạc sĩ - Bác sĩ',
      avatarUrl: 'doctor_044.png',
      biography: 'Bác sĩ thuộc Khoa Khám bệnh, có kinh nghiệm khám và tư vấn trong lĩnh vực chuyên khoa.'
    },
    { 
      id: 'mock_bs_2', 
      userId: 'mock_tk_bs2', 
      fullName: 'Nguyễn Thị Mai', 
      email: 'maint@mock.com', 
      phone: '0902222222', 
      specialtyId: 'mock_ck_2', 
      specialtyName: 'Khoa Thần Kinh', 
      yearsOfExperience: 10, 
      consultationFee: 250000, 
      isActive: true, 
      status: 'ACTIVE', 
      qualification: 'Tiến sĩ - Bác sĩ',
      avatarUrl: 'doctor_045.png',
      biography: 'Bác sĩ chuyên khoa Thần Kinh với 10 năm kinh nghiệm.'
    },
  ];

  // --- 3. TAI_KHOAN (Bệnh nhân) ---
  const accounts = [
    { id: 'mock_tk_bn1', email: 'benhnhan1@mock.com', fullName: 'Lê Văn An', phone: '0911111111', role: 'patient', isActive: true },
    { id: 'mock_tk_bn2', email: 'benhnhan2@mock.com', fullName: 'Phạm Thị Bình', phone: '0912222222', role: 'patient', isActive: true }
  ];

  // --- 4. BENH_NHAN ---
  const patients = [
    { id: 'mock_bn_1', authUserId: 'mock_tk_bn1', fullName: 'Lê Văn An', email: 'benhnhan1@mock.com', phone: '0911111111', gender: 'Nam', address: '123 Đường A, Quận 1', isActive: true },
    { id: 'mock_bn_2', authUserId: 'mock_tk_bn2', fullName: 'Phạm Thị Bình', email: 'benhnhan2@mock.com', phone: '0912222222', gender: 'Nữ', address: '456 Đường B, Quận 2', isActive: true }
  ];

  // --- 5. LICH_LAM_VIEC & CA_KHAM ---
  const workSchedules = [];
  const timeSlots = [];
  
  doctors.forEach((doc, index) => {
    const scheduleId = `mock_llv_${index + 1}`;
    workSchedules.push({
      id: scheduleId, doctorId: doc.id, workDate: tomorrowTimestamp, startTime: '08:00', endTime: '12:00', status: 'ACTIVE'
    });

    // 2 ca khám mỗi lịch
    timeSlots.push({ id: `mock_ca_${index + 1}_1`, workScheduleId: scheduleId, doctorId: doc.id, startTime: '08:00', endTime: '09:00', capacity: 5, bookedCount: 1, status: 'AVAILABLE' });
    timeSlots.push({ id: `mock_ca_${index + 1}_2`, workScheduleId: scheduleId, doctorId: doc.id, startTime: '09:00', endTime: '10:00', capacity: 5, bookedCount: 0, status: 'AVAILABLE' });
  });

  // --- 6. LICH_HEN ---
  const appointments = [
    { id: 'mock_lh_1', patientId: 'mock_bn_1', doctorId: 'mock_bs_1', workScheduleId: 'mock_llv_1', timeSlotId: 'mock_ca_1_1', specialtyId: 'mock_ck_1', appointmentDate: tomorrowTimestamp, startTime: '08:00', endTime: '09:00', status: 'PENDING', bookedAt: now, peopleCount: 1, reason: 'Khám tổng quát tim mạch' },
    { id: 'mock_lh_2', patientId: 'mock_bn_2', doctorId: 'mock_bs_2', workScheduleId: 'mock_llv_2', timeSlotId: 'mock_ca_2_1', specialtyId: 'mock_ck_2', appointmentDate: tomorrowTimestamp, startTime: '08:00', endTime: '09:00', status: 'CONFIRMED', bookedAt: now, peopleCount: 1, reason: 'Hay đau đầu chóng mặt' }
  ];

  // --- 7. THANH_TOAN (Extra) ---
  const payments = [
    { id: 'mock_tt_1', appointmentId: 'mock_lh_2', patientId: 'mock_bn_2', amount: 250000, paymentMethod: 'MOMO', status: 'SUCCESS', paymentDate: now },
    { id: 'mock_tt_2', appointmentId: 'mock_lh_1', patientId: 'mock_bn_1', amount: 180000, paymentMethod: 'VNPAY', status: 'PENDING', paymentDate: now }
  ];

  // --- 8. THONG_BAO (Extra) ---
  const notifications = [
    { id: 'mock_tb_1', userId: 'mock_tk_bn2', title: 'Lịch hẹn đã được xác nhận', message: 'Lịch hẹn lúc 08:00 với BS. Nguyễn Thị Mai đã được xác nhận thành công.', isRead: false, createdAt: now },
    { id: 'mock_tb_2', userId: 'mock_tk_bn1', title: 'Thanh toán đang chờ', message: 'Vui lòng hoàn tất thanh toán 180,000 VND cho lịch hẹn khám tim mạch.', isRead: true, createdAt: now }
  ];

  // --- 9. LS_CHAT_AI (Extra) ---
  const chatAiHistories = [
    { id: 'mock_chat_1', userId: 'mock_tk_bn1', sessionId: 'session_123', userMessage: 'Tôi bị đau tức ngực thì khám khoa nào?', aiReply: 'Dựa trên triệu chứng của bạn, bạn nên đặt lịch khám tại Khoa Tim Mạch. Bạn có muốn tôi hỗ trợ đặt lịch không?', timestamp: now },
    { id: 'mock_chat_2', userId: 'mock_tk_bn1', sessionId: 'session_123', userMessage: 'Có, đặt giúp tôi.', aiReply: 'Vui lòng chọn bác sĩ và thời gian bạn muốn khám.', timestamp: now }
  ];

  const allCollections = {
    CHUYEN_KHOA: specialties,
    BAC_SI: doctors,
    TAI_KHOAN: accounts,
    BENH_NHAN: patients,
    LICH_LAM_VIEC: workSchedules,
    CA_KHAM: timeSlots,
    LICH_HEN: appointments,
    THANH_TOAN: payments,
    THONG_BAO: notifications,
    LS_CHAT_AI: chatAiHistories
  };

  let totalDocs = 0;
  for (const list of Object.values(allCollections)) totalDocs += list.length;

  console.log(`Đã chuẩn bị ${totalDocs} documents cho ${Object.keys(allCollections).length} bảng.`);

  if (!apply) {
    console.log('\n[Dry Run] Chạy thử thành công! Không có dữ liệu nào được ghi vào Firestore.');
    console.log('Để ghi dữ liệu thật, hãy chạy lệnh với cờ: --apply (hoặc npm run seed-mock:apply)');
    return;
  }

  console.log('\n[Apply] Đang ghi dữ liệu lên Firestore...');
  const batch = firestore.batch();

  for (const [collectionName, dataList] of Object.entries(allCollections)) {
    for (const item of dataList) {
      const docRef = firestore.collection(collectionName).doc(item.id);
      const data = { ...item, createdAt: now, updatedAt: now };
      delete data.id; // Xóa ID vì đã dùng làm docId
      batch.set(docRef, data);
    }
  }

  await batch.commit();
  console.log('✅ Đã ghi toàn bộ dữ liệu mẫu lên Firestore thành công!');
}

seedMockData().catch((error) => {
  console.error('❌ Có lỗi xảy ra:', error);
});
