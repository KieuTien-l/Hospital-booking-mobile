# Đối chiếu nghiệm thu ADM và giao diện chatbot

Phạm vi: ADM-02, ADM-05, ADM-08, ADM-12, ADM-15, ADM-18, ADM-20 và S6-08
theo 8 ảnh yêu cầu ngày 22/10/2026. Thay đổi thực hiện trên nhánh NgocVan.

| Yêu cầu | Thực hiện và xử lý lỗi | Kiểm chứng |
| --- | --- | --- |
| ADM-02: thống kê tổng quan | Đọc chuyên khoa, bác sĩ và lịch hẹn từ repository Firebase. Giữ đăng ký stream xuyên suốt lần tải đầu, tránh mất sự kiện. Dữ liệu rỗng có trạng thái riêng; lỗi quyền xóa số liệu đã tải và không bị sự kiện từ nguồn khác che mất. | `admin_controllers_test.dart`, emulator `requirements.test.js` |
| ADM-05: repository bác sĩ | Ánh xạ theo document ID; chịu được thiếu trường tùy chọn; trả hồ sơ ngừng hoạt động khi tra lịch sử. Không nhận hồ sơ ARCHIVED hoặc trạng thái lạ là đang hoạt động. Phát hiện tài khoản trùng nhiều hồ sơ; giữ thông tin cá nhân và cờ nhận lịch khi lưu/chuyển chuyên khoa. Hỗ trợ liên kết accountKey cũ trong workspace. | `admin_firebase_repositories_test.dart`, `models_test.dart`, emulator |
| ADM-08: repository chuyên khoa | Đọc cả danh mục cho admin; lọc chính xác trạng thái cho patient. Ghi đúng collection/field hiện có, kiểm tra tên, trạng thái và quyền admin ở Security Rules. | Repository test và emulator |
| ADM-12: lịch/ca Firebase | Kiểm tra bác sĩ/lịch cha, định dạng và thứ tự giờ, giờ nằm trong lịch làm việc, sức chứa, số chỗ giữ. Chặn thay đổi chủ sở hữu, làm sai bộ đếm hoặc xóa ca đang có người đặt. Repository kiểm tra quy tắc cuối tuần và giữ trạng thái khóa ca. | Emulator `requirements.test.js`, các test lịch/đặt chỗ hiện có |
| ADM-15: quyền đọc và nhất quán lịch hẹn | Query theo doctor/patient hợp lệ; query rộng, dữ liệu người khác hoặc hồ sơ bác sĩ đã ngừng hoạt động bị chặn. Admin đọc toàn bộ. Đổi filter thực sự tải lại; kết quả bất đồng bộ cũ không đè dữ liệu mới. Đối chiếu bác sĩ/ngày/lịch/ca/giờ/sức chứa; giữ snapshot chuyên khoa lịch sử. Lịch đã hủy không phải giữ chỗ nữa và vẫn hợp lệ nếu sức chứa ca được giảm sau đó; lịch sử có thể đối chiếu lịch đã đóng. | `admin_workflow_controllers_test.dart`, emulator |
| ADM-18: dữ liệu yêu cầu | Bổ sung `YEU_CAU_BAC_SI`: gửi từ workspace bác sĩ, xem lịch sử, admin duyệt/trả lời trong mục Yêu cầu bác sĩ. Lưu senderId/doctorId/scheduleId, nội dung, createdAt; backend lấy reviewedBy từ phiên admin và đặt reviewedAt bằng thời gian máy chủ. Chặn giả người gửi/người duyệt và sửa nội dung sau khi gửi; retry cùng mã không tạo bản trùng. Duyệt trong transaction có nhật ký. | Repository test; emulator kiểm tra gửi, quyền, phản hồi, timestamp, retry và duyệt lần hai |
| ADM-20: tài khoản và quyền | Admin truy vấn tài khoản theo trạng thái, duyệt patient PENDING; patient chỉ xem hồ sơ mình và sửa trường cho phép. Chặn tự duyệt, tự thay role, thay role bằng quyền client admin, tài khoản khóa và truy cập trái quyền. | Emulator, `admin_workflow_controllers_test.dart` |
| S6-08: giao diện chatbot | Mở từ Home/Chức năng; nhập/gửi, hiển thị hội thoại đúng thứ tự, nhãn Bạn/HealWay, chờ phản hồi, khóa gửi trùng, lỗi và thử lại giữ nguyên câu hỏi. Tự cuộn tới tin mới; kiểm tra văn bản dài, chữ lớn, màn 320px và bàn phím. | `patient_support_page_test.dart`, `patient_home_test.dart` |

## Dữ liệu yêu cầu bác sĩ

- Collection: `YEU_CAU_BAC_SI`.
- Trường tạo: `senderId`, `doctorId`, `scheduleId`, `type`, `date`, `reason`,
  `description`, `status=PENDING`, `createdAt`, `updatedAt`.
- `date` giữ timestamp ngày làm việc của lịch được chọn, tránh đổi ngày do chuẩn hóa timezone.
- Trường xử lý: `status=APPROVED|REJECTED|RESOLVED`, `adminResponse`,
  `reviewedBy`, `reviewedAt`, `updatedAt`.
- Người gửi không chỉnh/sửa/xóa yêu cầu đã gửi. Admin xử lý qua
  `adminCommand(operation=reviewDoctorRequest)`, không ghi client trực tiếp.
- Lịch sử bác sĩ lọc bằng `senderId`; không cần composite index mới.

## Kiểm tra lại

Kết quả sau rà soát lại: toàn bộ **303 Flutter test đạt**; phân tích mã **không có cảnh báo/lỗi**.
Bộ Firebase emulator gồm **35 test đạt**, kiểm tra cả các ca được phép và bị từ chối.
Giao diện danh sách/duyệt yêu cầu và chatbot đã được kiểm tra qua ảnh chụp từ widget test.

Lượt rà soát lại bổ sung kiểm thử tái hiện và sửa ba lỗi:

1. Backend admin chỉ cập nhật `bookedCount` nhưng bỏ sót `reservationCounts` khi đặt/hủy/đổi lịch.
   Các thao tác này hiện dựng lại bảng giữ chỗ từ lịch hẹn trong cùng transaction,
   kiểm tra tổng số chỗ và cập nhật đồng bộ cả ca cũ lẫn ca mới. Hỗ trợ ca cũ chưa có bảng giữ chỗ.
2. Bộ đối chiếu lịch hẹn coi chuyên khoa hiện tại và sức chứa hiện tại là điều kiện bắt buộc
   cho lịch sử đã hủy. Nay giữ chuyên khoa tại thời điểm đặt và không yêu cầu lịch đã hủy
   phải còn giữ chỗ hoặc vừa sức chứa đã giảm sau này.
3. Security Rules trước đây chỉ xét `BAC_SI.status`, bỏ sót `isActive=false`.
   Bác sĩ có hồ sơ ngừng hoạt động hiện không đọc được lịch hẹn dù tài khoản đăng nhập còn hoạt động.

```powershell
flutter analyze --no-pub
flutter test --no-pub
npm run test:emulator --prefix functions
```

Test emulator chỉ dùng các project `demo-*`, không thao tác Firebase production.
`test/firestore_rules.test.mjs` lấy host/port từ `FIRESTORE_EMULATOR_HOST` để có
thể chạy bộ kiểm thử ở cổng riêng.

## Phạm vi triển khai

Mã nguồn đã có luồng gửi/duyệt yêu cầu. Cần triển khai `firestore.rules` và
Cloud Function `adminCommand` cùng phiên bản app để dùng các thay đổi trên
Firebase thật. Đợt thực hiện này không deploy hoặc sửa dữ liệu production.

S6-08 yêu cầu giao diện. Chatbot mặc định trả hướng dẫn sử dụng HealWay cục bộ,
không gọi mô hình AI bên ngoài. `answerQuestion` là adapter bất đồng bộ để nối
dịch vụ AI khi backend đó được cung cấp; cùng UI đã kiểm thử cả chờ/lỗi/retry.
