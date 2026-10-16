# Nghiệm thu DOC-13, DOC-16, DOC-18, DOC-19 và DOC-21

## Phạm vi

Tài liệu này ghi nhận phần đã tích hợp trong HealWay. Dữ liệu trên Firestore
được coi là nguồn xác thực; ứng dụng không tạo dữ liệu lịch, bác sĩ hoặc ca
khám giả khi không có kết quả truy vấn.

| Hạng mục | Mô tả đã thực hiện | Bằng chứng mã nguồn | Kết quả |
| --- | --- | --- | --- |
| DOC-13 – Truy vấn lịch khám theo Doctor ID | Tìm `LICH_LAM_VIEC` theo `doctorId`, chỉ lấy lịch `ACTIVE`; lấy các `CA_KHAM` thuộc lịch, lọc ca còn chỗ và gom theo ngày/bác sĩ. `whereIn` được chia nhóm tối đa 30 ID để tôn trọng giới hạn Firestore. | `WorkScheduleFirebaseDatasource`, `TimeSlotFirebaseDatasource`, `ScheduleController` | Đạt |
| DOC-16 – Kiểm tra quyền truy cập | Rules yêu cầu đăng nhập và tài khoản hoạt động cho dữ liệu nghiệp vụ. Lịch hẹn chỉ đọc được bởi bệnh nhân sở hữu, bác sĩ phụ trách hoặc quản trị viên; bác sĩ được xác minh từ `TAI_KHOAN` và `BAC_SI`. | `firestore.rules`: `hasActiveAccount`, `ownsPatient`, `isDoctor`, `LICH_HEN` | Đạt |
| DOC-18 – Model và Repository yêu cầu | `Appointment`/`AppointmentModel` chuyển đổi dữ liệu Firestore an toàn; `AppointmentRepository` tách contract domain với Firebase datasource/repository implementation. Các model bác sĩ, lịch làm việc và ca khám cũng được dùng để kiểm tra quan hệ trước khi lưu. | `features/appointments/domain`, `features/appointments/data`, `features/doctors/data/models` | Đạt |
| DOC-19 – Lưu yêu cầu lên Firestore | `createAppointment` dùng một transaction: xác minh lịch/ca/bác sĩ/bệnh nhân, tạo `LICH_HEN`, cập nhật sức chứa `CA_KHAM` và tạo thông báo `THONG_BAO`. Hủy/đổi lịch cũng giải phóng/chuyển sức chứa trong transaction. Rules đã dùng đúng path `THONG_BAO`. | `AppointmentFirebaseDatasource`, `firestore.rules` | Đạt |
| DOC-21 – Kiểm tra phân quyền | Quyền được phân tách theo `patient`, `doctor`, `admin`; bệnh nhân chỉ sửa đúng tập dữ liệu cho phép, bác sĩ chỉ cập nhật lịch hẹn/lịch làm việc của mình, quản trị viên quản lý toàn bộ. | `firestore.rules` | Đạt |

## Kịch bản nghiệm thu chính

1. Người dùng đã đăng nhập chọn chuyên khoa; ứng dụng gọi
   `getDoctorsBySpecialty`, truy vấn lịch theo từng `doctorId`, rồi chỉ hiển
   thị các ca còn khả dụng trong năm ngày bắt đầu từ ngày được chọn.
2. Khi xác nhận đặt khám, transaction từ chối bác sĩ/lịch/ca không tồn tại,
   ca không còn chỗ, hoặc dữ liệu ngày giờ không khớp. Nếu hợp lệ, lịch hẹn,
   số lượng đã đặt và thông báo được ghi cùng lúc.
3. Bệnh nhân chỉ đọc/sửa lịch hẹn và thông báo thuộc hồ sơ của mình. Bác sĩ
   chỉ xem/cập nhật lịch hẹn có `doctorId` trùng hồ sơ bác sĩ gắn với tài khoản
   đang đăng nhập. Các thao tác ngoài quyền bị Firestore Rules từ chối.

## Kiểm thử tự động

- `test/features/data/models_test.dart` kiểm tra ánh xạ model, Document ID,
  Timestamp, giá trị thiếu và kiểu số.
- `test/features/appointments/data/appointment_booking_test.dart` kiểm tra
  transaction đặt/hủy/đổi lịch, kiểm đếm sức chứa và payload `THONG_BAO`.
- `test/features/appointments/presentation/select_appointment_time_page_test.dart`
  kiểm tra truy vấn batch lịch/ca theo bác sĩ và chuyển ID thật vào luồng đặt
  lịch.
- `test/features/doctors/presentation/doctor_dashboard_controller_test.dart`
  kiểm tra việc chỉ tải lịch hẹn của bác sĩ đã xác thực.
- `test/firestore_rules.test.mjs` chạy bằng Firestore Emulator, kiểm tra năm
  trường hợp Rules: bệnh nhân đọc đúng lịch hẹn/thông báo, chỉ đánh dấu đã đọc
  thông báo của mình, bác sĩ chỉ xem lịch được phân công, quản trị viên được
  xem mọi lịch và khách chưa đăng nhập bị từ chối.

Chạy kiểm tra Rules tại máy cục bộ:

```text
npm run test:firestore-rules
```

Lần chạy nghiệm thu gần nhất trên Firestore Emulator: **5/5 PASS**.

## Giới hạn xác minh

Bộ test hiện dùng Firestore giả lập ở tầng client. Trước khi phát hành cần
deploy `firestore.rules` và thực hiện smoke test trên Firebase với ba vai trò
patient/doctor/admin để xác minh quyền ở máy chủ.
