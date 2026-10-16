# Tích hợp backend cho giao diện bác sĩ

## Phạm vi đã triển khai

- Repository riêng `DoctorWorkspaceRepository`, hai nguồn demo và HTTP; không đổi repository hoặc luồng đặt khám của bệnh nhân.
- Controller tải theo ngày, bỏ kết quả cũ khi đổi ngày, giữ dữ liệu cũ khi lỗi mạng trong cùng ngày, xóa dữ liệu khi bị từ chối quyền hoặc phản hồi sai bác sĩ.
- Trang chủ và chi tiết ca dùng chung controller, tự tải lại mỗi 30 giây ở chế độ thật và có nút Làm mới/Thử lại. Đây là polling, chưa phải stream thời gian thực từ server.
- Navigator riêng cho bác sĩ bị hủy cùng dữ liệu khi AuthGate mất phiên hoặc đổi tài khoản. Dialog bác sĩ cũng nằm trong navigator này.
- Báo cáo có tải ca phân công, gửi chống bấm trùng, giữ nội dung khi lỗi, retry cùng idempotency key, lịch sử và phản hồi Admin.
- Hồ sơ dùng các trường chuyên môn/ảnh đã có trong Doctor; vẫn chỉ đọc. Các mục đào tạo, hiệp hội, nghiên cứu chưa có schema nên giữ trạng thái chưa có dữ liệu.
- Không thay đổi/deploy Firestore rules, không gửi mẫu lên Firebase, không cấp quyền đọc toàn bộ BENH_NHAN.

## Cấu hình

Debug mặc định dùng mẫu. Release mặc định dùng nguồn thật. Có thể chọn rõ khi chạy:

```powershell
flutter run --dart-define=DOCTOR_DEMO=true
flutter run --dart-define=DOCTOR_DEMO=false --dart-define=DOCTOR_API_BASE_URL=https://backend.example.com/api
```

URL phải là HTTPS, không chứa thông tin đăng nhập, query hoặc fragment. Không có URL sẽ báo thiếu cấu hình; không tự chuyển sang demo.

Mọi request gửi `Authorization: Bearer <Firebase ID token>`. Server phải xác minh token, tài khoản đang hoạt động, role doctor, và tra `BAC_SI.userId == token.uid`. Không tin doctorId/userId do client cung cấp. 401 kết thúc phiên của đúng tài khoản đã gửi request; 403 xóa dữ liệu được bảo vệ và hiện lỗi quyền.

## GET /doctor/day?date=YYYY-MM-DD

Ngày là ngày lịch bệnh viện theo Asia/Ho_Chi_Minh. Trả đầy đủ lịch, ca và lịch hẹn của bác sĩ hiện tại trong ngày, kể cả các ca đã đủ chỗ. Các trường ngày lịch dùng `YYYY-MM-DD`; không dịch ngày qua UTC.

```json
{
  "doctor": {
    "id": "doctor-1", "userId": "firebase-uid",
    "fullName": "Tên bác sĩ", "email": "doctor@example.com", "phone": "",
    "specialtyId": "noi", "specialtyName": "Nội tổng quát",
    "qualification": "Thạc sĩ", "yearsOfExperience": 10,
    "consultationFee": 100000, "isActive": true, "status": "ACTIVE",
    "avatarUrl": "https://example.com/avatar.jpg"
  },
  "schedules": [
    {"id": "schedule-1", "doctorId": "doctor-1", "workDate": "2026-10-19", "startTime": "06:30", "endTime": "11:30", "status": "ACTIVE"}
  ],
  "slots": [
    {"id": "slot-1", "workScheduleId": "schedule-1", "doctorId": "doctor-1", "startTime": "06:30", "endTime": "07:30", "status": "AVAILABLE", "capacity": 3, "bookedCount": 1}
  ],
  "bookings": [
    {
      "appointment": {
        "id": "appointment-1", "patientId": "patient-1", "doctorId": "doctor-1",
        "workScheduleId": "schedule-1", "timeSlotId": "slot-1",
        "appointmentDate": "2026-10-19", "startTime": "06:30", "endTime": "07:30",
        "status": "CONFIRMED", "peopleCount": 1, "queueNumber": 1, "reason": "Khám định kỳ"
      },
      "patientName": "Tên bệnh nhân", "birthYear": 1990, "gender": "Nữ"
    }
  ]
}
```

Server trả projection tên/năm sinh/giới tính theo lịch được phân công; không yêu cầu client đọc trực tiếp hồ sơ bệnh nhân. Không có lịch trả ba mảng rỗng. Không tìm thấy bác sĩ/phân quyền thất bại phải trả lỗi, không giả thành danh sách rỗng.

Thứ bảy chỉ có lịch và ca trước 12:00, Chủ nhật không có lịch. Backend cần kiểm tra tại thao tác tạo/sửa lịch; client kiểm tra lại phản hồi, không âm thầm ẩn lịch sai quy tắc. ID phải duy nhất; mọi liên kết bác sĩ/lịch/ca/ngày phải nhất quán.

### Trạng thái và thống kê

- Ca: CANCELLED → Đã hủy; UNAVAILABLE/BLOCKED → Tạm ngưng; BOOKED → Đã đặt hết; AVAILABLE với bookedCount/capacity hợp lệ → xanh nếu còn chỗ, xám nếu đầy. Thiếu số chỗ hoặc UNKNOWN → Chưa xác định số chỗ.
- Đã đặt tính tổng `peopleCount` của PENDING, CONFIRMED, COMPLETED, NO_SHOW; không tính CANCELLED/UNKNOWN.
- Đã khám chỉ COMPLETED; Chờ khám chỉ CONFIRMED; Chờ xác nhận chỉ PENDING. Các nhóm không bị gộp nhầm. NO_SHOW hiển thị Vắng mặt ở danh sách.
- `bookedCount` là số chỗ đã giữ, không phải số document lịch hẹn. Backend phải cập nhật bộ đếm và trạng thái ca nguyên tử khi đặt/hủy/thay đổi lịch.
- Danh sách phản hồi phải đầy đủ để tính tổng; không trả một trang danh sách như thể đó là toàn bộ ngày.

## Báo cáo

`GET /doctor/reports` trả `{ "reports": [ ... ] }` của bác sĩ đang đăng nhập.

`POST /doctor/reports` gửi header `Idempotency-Key` và body:

```json
{
  "type": "Bận đột xuất", "scheduleId": "schedule-1", "date": "2026-10-19",
  "reason": "Lý do", "description": "Mô tả chi tiết"
}
```

Type thuộc `Bận đột xuất`, `Sự cố lịch làm`, `Khác`. Reason bắt buộc, tối đa 200 ký tự; description bắt buộc, tối đa 1000 ký tự. Server xác minh ca thuộc bác sĩ và đúng ngày. Gửi báo cáo không tự sửa lịch.

POST trả report trực tiếp, GET dùng cùng schema trong mảng reports:

```json
{"id":"report-1","type":"Bận đột xuất","date":"2026-10-19","reason":"Lý do","status":"PENDING","adminResponse":null}
```

Trạng thái: PENDING, APPROVED, REJECTED, RESOLVED. Server lưu khóa chống trùng theo tài khoản, trả cùng report khi retry cùng khóa/body; cùng khóa với body khác phải báo conflict. Đây là yêu cầu backend để không tạo hai báo cáo khi response đầu tiên bị mất.

## Còn cần phía backend

Triển khai các endpoint trên, phân quyền/projection bệnh nhân, quy tắc cuối tuần, transaction bộ đếm ca và lưu idempotency key. Chưa có server/URL trong repo để nghiệm thu end-to-end; các adapter đã được kiểm thử bằng HTTP giả lập. Firestore rules hiện tại vẫn giữ nguyên.
