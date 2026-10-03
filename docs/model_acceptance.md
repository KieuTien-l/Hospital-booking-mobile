# Nghiệm thu Dart Models – Patient Module

## Mục tiêu

Hoàn thiện các Dart Model phục vụ hồ sơ bệnh nhân và đặt lịch khám. Mỗi
model ánh xạ một collection Cloud Firestore, có thể chuyển dữ liệu Firestore
thành Dart object an toàn và được Repository sử dụng trực tiếp.

Luồng dữ liệu:

`Specialty → Doctor → WorkSchedule → TimeSlot → Appointment → Patient`

## Kết quả nghiệm thu

| Model | Collection | Field chuẩn trên Firestore | Kết quả |
| --- | --- | --- | --- |
| `Specialty` | `CHUYEN_KHOA` | `name`, `description`, `imageUrl`, `status`, `isActive`, `createdAt`, `updatedAt` | Đạt |
| `Doctor` | `BAC_SI` | `userId`, `fullName`, `email`, `phone`, `specialtyId`, `yearsOfExperience`, `consultationFee`, `status`, `isActive` | Đạt |
| `WorkSchedule` | `LICH_LAM_VIEC` | `doctorId`, `workDate`, `startTime`, `endTime`, `status`, `createdAt`, `updatedAt` | Đạt |
| `TimeSlot` | `CA_KHAM` | `workScheduleId`, `doctorId`, `startTime`, `endTime`, `bookedCount`, `capacity`, `appointmentId`, `status` | Đạt |
| `Appointment` | `LICH_HEN` | `patientId`, `doctorId`, `workScheduleId`, `timeSlotId`, `specialtyId`, `appointmentDate`, `startTime`, `endTime`, `status` | Đạt |
| `Patient` | `BENH_NHAN` | `authUserId`, `fullName`, `phone`, `email`, `dateOfBirth`, `status`, `isActive` | Đạt |

Tất cả sáu model đều:

- Nhận Document ID từ `DocumentSnapshot`.
- Có `fromFirestore` và `fromMap` để chuyển `Map<String, dynamic>` thành
  Dart object.
- Xử lý an toàn field thiếu hoặc `null`.
- Chuyển đúng `Timestamp`, `DocumentReference`, số nguyên và số thực về kiểu
  Dart phù hợp.
- Có `toFirestore` để ghi dữ liệu theo schema chuẩn.

## Tích hợp Repository và kiểm thử

`FirebasePatientBookingRepository` sử dụng trực tiếp sáu model khi đọc các
collection trên. Bộ kiểm thử model kiểm tra mapping quan hệ chuyên khoa – bác
sĩ – lịch làm việc – ca khám – lịch hẹn – bệnh nhân, dữ liệu `Timestamp`, số
đếm ca khám và payload thiếu field.

## Schema đồng nhất

Schema chính thức chỉ dùng field tiếng Anh. Trước khi chạy ứng dụng với phiên
bản này, chạy migration trong `scripts/migrate-firestore.mjs` để copy dữ liệu
từ field tiếng Việt sang field chuẩn, xác minh kết quả, rồi chạy cleanup để
xóa các field tiếng Việt. Model và Repository không còn đọc field tiếng Việt.
