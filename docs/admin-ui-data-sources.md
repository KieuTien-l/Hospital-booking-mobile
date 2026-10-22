# Giao diện quản trị HealWay

> Cập nhật nghiệp vụ ngày 21/10/2026: đã bổ sung thao tác ghi qua backend,
> quyền hồ sơ bác sĩ, cấu hình thật và kiểm thử emulator. Xem
> [admin-management.md](admin-management.md) để biết trạng thái hiện tại và
> cách triển khai. Những đoạn chỉ đọc/DEMO/quyền chưa bổ sung bên dưới là lịch
> sử của đợt làm giao diện trước đó.

## Làm lại giao diện — 21/10/2026

Đợt này hoàn thiện lớp giao diện và tra cứu, giữ nguyên repository chỉ đọc,
Firestore Rules, đăng nhập và nghiệp vụ patient/doctor hiện có. Tái sử dụng
`PatientHomeBackground` theo cách chỉ import, không sửa widget hay theme chung.
Theme màu xanh dương, chữ Be Vietnam Pro và các thẻ bo góc chỉ áp dụng trong admin.
Không thêm thư viện hoặc thay đổi cấu trúc dữ liệu Firebase.

### Đồng bộ các trang còn lại theo Tổng quan

- Tất cả 14 mục còn lại dùng thanh tiêu đề trắng gọn với icon phía trước,
  bỏ tên bệnh viện và avatar dư ở thanh tiêu đề. Font và màu chỉ áp dụng cho admin.
- Các trang dữ liệu dùng thẻ giới thiệu xanh chuyển nhẹ, số tổng bản ghi và
  bản ghi mẫu căn giữa; nền trắng nối từ tiêu đề xuống nửa thẻ đầu như Tổng quan.
- Thẻ danh sách có icon trước tiêu đề; khu vực tìm kiếm/lọc có nền xanh rất
  nhạt, ô nhập bo góc và dropdown mở rộng vừa chiều ngang trên điện thoại.
- Thẻ bản ghi, thẻ bác sĩ, các ô cấu hình và trường trong chi tiết dùng nền
  xanh nhạt, viền mảnh và khoảng cách thống nhất. Chi tiết và bộ chọn ngày dùng
  chung theme admin để giữ đúng font và màu trên các cửa sổ nổi.
- Giữ nguyên repository, controller, nguồn dữ liệu, các bộ lọc, phân trang,
  điều hướng, quyền đọc và các trạng thái lỗi/DEMO; không bổ sung thao tác ghi.
- Widget test render từng mục trên 1440 px và 390 px tại
  `build/admin-preview/section-<thứ tự menu>-<chiều rộng>.png`; dữ liệu giả lập.
- Xác minh sau đồng bộ: `flutter analyze` không có vấn đề, 11/11 test admin
  đạt. Toàn bộ test: 239 đạt, còn đúng một lỗi patient đã có từ mốc trước sửa
  (`Patient home supports small screens, search and navigation`).

### Đã thực hiện

- Menu nhóm theo công việc: tổng quan, điều hành khám, danh mục, tài chính &
  chăm sóc, quản trị, tra cứu mở rộng, hệ thống. Giữ quyền truy cập đủ 15 mục cũ.
- Tổng quan: hộp chọn hôm nay/tháng này/năm nay/khoảng tùy chọn; tháng và năm
  tính đủ kỳ theo lịch Việt Nam (bao gồm lịch khám sắp tới trong kỳ).
  Thẻ chào được rút gọn; tiêu đề thống kê kèm icon bên trái, bộ lọc bên phải;
  không hiển thị dòng khoảng ngày dưới tiêu đề.
  Các thẻ chỉ số có icon cạnh tiêu đề, số và ghi chú căn giữa.
  Bốn chỉ số lịch khám,
  chờ xác nhận, hoàn thành, tiền đã thu. Bấm chỉ số mở danh sách theo đúng kỳ
  và trạng thái, kể cả khi trạng thái chưa có bản ghi.
- Tiền đã thu chỉ cộng giao dịch PAID/SUCCESS có `paidAt` trong kỳ và số tiền
  hợp lệ không âm. Không thay ngày thanh toán bằng ngày tạo giao dịch. Giao dịch
  thành công thiếu `paidAt` được nêu rõ và không cộng vào tổng.
- Biểu đồ lượt khám bảy ngày cuối trong khoảng chọn; phân bổ theo chuyên khoa;
  lịch khám trong kỳ; lịch bác sĩ hôm nay cùng số chỗ đặt nếu đủ dữ liệu ca khám.
- Khối theo dõi hiển thị lịch chờ trên toàn dữ liệu, lịch hủy trong kỳ và tổng
  phản hồi đã nhận. Không suy diễn phản hồi chưa có trạng thái là chưa xử lý.
- Lịch hẹn: tab trạng thái, kết hợp tìm kiếm/ngày/bác sĩ/chuyên khoa, xóa bộ lọc,
  giữ điều kiện và trang khi chuyển mục. Tra cứu cả số điện thoại hồ sơ liên kết.
- Bác sĩ dùng lưới thẻ; lịch làm việc có chế độ danh sách/theo ngày; màn hình
  hẹp dùng thẻ thông tin thay cho bảng cuộn ngang.
- Chi tiết chia tab thông tin/liên quan/dữ liệu mở rộng. Bệnh nhân liên kết
  lịch hẹn, giao dịch, hồ sơ và kết quả CLS; bác sĩ liên kết lịch hẹn/lịch làm
  việc; lịch làm việc liên kết ca khám/lịch hẹn; chuyên khoa liên kết bác sĩ;
  tài khoản liên kết hồ sơ bác sĩ và bệnh nhân. Lỗi quyền trong từng nhóm liên
  quan vẫn hiển thị riêng và có nút thử lại.

### Còn lại trong kế hoạch nghiệp vụ

Chưa triển khai thao tác ghi: tạo/duyệt/đổi/hủy lịch, thêm/sửa bác sĩ và chuyên
khoa, tạo lịch và sinh ca, gửi thông báo, xử lý phản hồi, sửa quyền tài khoản,
đối soát/hoàn tiền, lưu cấu hình, báo cáo chuyên sâu/xuất file và nhật ký hoạt
động. Không có nút giả thành công cho các chức năng này. Những phần đó cần
kiểm tra hợp đồng backend, quyền và tính nhất quán của ca khám trước khi nối
vào dữ liệu hoạt động. Cấu hình vẫn là minh họa có nhãn, chưa áp dụng nghiệp vụ.

### Kiểm tra đợt giao diện

- `flutter analyze`: không có vấn đề.
- `flutter test test/features/admin --dart-define=ADMIN_CAPTURE=true`: kiểm tra
  **11/11 bài đạt**; kiểm tra
  bộ lọc, phân quyền đọc, phục hồi lỗi, điều hướng từ chỉ số, giữ bộ lọc,
  liên kết bản ghi, đủ 15 trang trên desktop/mobile, ngày Việt Nam và phép
  tính tiền đã thu; kiểm tra 320 px với cỡ chữ 130%.
- Chạy toàn bộ test sau sửa: 237 đạt, 1 lỗi có sẵn tại
  `Patient home supports small screens, search and navigation` trong
  `test/patient_home_test.dart` (overflow ở thông báo và thiếu nhãn kỳ vọng).
  Chạy mốc trước khi sửa cũng có đúng lỗi này (232 đạt, 1 lỗi).
  Sau đó bổ sung riêng một bài kiểm tra điều hướng đủ 15 mục admin.
- Ảnh render `build/admin-preview/overview-populated-1440.png`,
  `appointments-1440.png`, `doctors-1440.png`, `schedules-1440.png`,
  `appointment-detail-1440.png`, `overview-390.png`, `appointments-320.png`
  dùng repository giả lập của widget test, không phải dữ liệu production.
- Chưa xác minh bằng phiên admin đăng nhập trên Firebase đang triển khai.

Trang admin sử dụng tuyến phân quyền admin hiện có, hỗ trợ màn hình rộng và
điện thoại. Phạm vi triển khai: tổng quan, tra cứu, tìm kiếm, lọc trạng thái,
lọc ngày lịch hẹn/lịch làm việc, phân trang giao diện và xem chi tiết.
Không có thao tác tạo/sửa/xóa hay thay đổi quy trình đặt khám, khám và thanh toán.

## Nguồn Firebase đã kiểm tra

Kiểm tra chỉ đọc tên collection và tên trường trên dự án `bookinghospitalapp`
ngày 20/10/2026. Tất cả collection sau đều có ít nhất một bản ghi tại thời điểm
kiểm tra. Đây là dữ liệu lưu trên Firebase; không đồng nghĩa tất cả là dữ liệu
nghiệp vụ thực tế. Nhiều collection có `seedVersion`, `source` hoặc `isTestData`.
Giao diện gắn nhãn **Mẫu trên Firebase** khi nhận diện được các dấu hiệu này.

| Mục giao diện | Collection | Trường chính |
| --- | --- | --- |
| Lịch hẹn | LICH_HEN | patientId, doctorId, appointmentDate, startTime, status |
| Bác sĩ | BAC_SI | fullName, specialtyId, consultationFee, status |
| Bệnh nhân | BENH_NHAN | fullName, phone, dateOfBirth, status |
| Chuyên khoa | CHUYEN_KHOA | name, description, status |
| Lịch làm việc | LICH_LAM_VIEC | doctorId, workDate, startTime, endTime |
| Ca khám | CA_KHAM | doctorId, workScheduleId, bookedCount, capacity |
| Thanh toán | THANH_TOAN | transactionCode, amount, paymentMethod, status |
| Phản hồi | PHAN_HOI | title, patientId, rating, category |
| Tài khoản | TAI_KHOAN | fullName, email, role, isActive |
| Hồ sơ sức khỏe | HO_SO_SUC_KHOE | patientId, doctorId, recordDate, diagnosis |
| Kết quả CLS | KET_QUA_CLS | patientId, testName, testDate, conclusion |
| Thông báo | THONG_BAO | title, patientId, content, isRead |
| Tư vấn AI | LS_CHAT_AI | userId, userMessage, aiReply, timestamp |

## Những chỗ chưa có dữ liệu thật

- **Cấu hình hệ thống**: chưa tìm thấy collection cấu hình. Giờ tiếp nhận,
  nhắc lịch và email hỗ trợ là DEMO cục bộ, có ghi chú trong giao diện, không
  được áp dụng vào luồng hoạt động.
- Nếu một collection trả về kết quả rỗng đã xác nhận từ máy chủ: mục tra cứu
  hiển thị một bản ghi DEMO có banner giải thích. Không ghi demo lên Firebase.
- Trường bị thiếu hiển thị **Chưa có dữ liệu**. Không suy diễn giá trị còn thiếu.
- Các chỉ số và biểu đồ tổng quan chỉ đếm bản ghi Firebase, gồm cả bản ghi mẫu
  đã lưu nếu có; không cộng DEMO cục bộ. Không dựng số tăng trưởng hay doanh thu giả.

## Quyền truy cập và giới hạn

- App dùng Cloud Firestore client SDK với phiên đăng nhập hiện tại; không chứa
  service account, private key hoặc bỏ qua quyền truy cập.
- `firestore.rules` trong repository hiện cho admin đọc bảy collection nghiệp vụ
  đặt khám và tài khoản. Chưa có rule cho THANH_TOAN, PHAN_HOI, HO_SO_SUC_KHOE,
  KET_QUA_CLS, THONG_BAO, LS_CHAT_AI. Nếu rules đang triển khai tương tự, những
  mục đó sẽ báo thiếu quyền và có nút thử lại. Không tự sửa/deploy rules.
- Lỗi mạng, kết quả chỉ từ cache hoặc lỗi quyền được thông báo; không thay lỗi
  bằng demo và không hiển thị thống kê cũ như dữ liệu mới.
  Người dùng có thể chọn **Xem giao diện DEMO** để xem thiết kế khi chưa đọc được
  dữ liệu. Banner lỗi và nhãn DEMO vẫn hiển thị; đây không phải xác nhận collection rỗng.
- Listener được hủy khi rời admin/đổi phiên. Các phần patient/doctor và provider
  dùng chung không thay đổi.
- Phân trang hiện ở giao diện (10 dòng/trang); listener đọc toàn bộ collection
  để tính tổng và tìm kiếm chính xác. Với dữ liệu lớn, cần backend tổng hợp và
  phân trang truy vấn trước khi mở rộng vận hành.
- Kiểm tra cấu trúc Firebase bằng service account chỉ xác nhận sự tồn tại;
  không xác nhận quyền đọc của một phiên admin cụ thể.

## Kiểm tra

`flutter analyze` và `flutter test`.
Các test admin kiểm tra phân biệt dữ liệu rỗng/lỗi quyền, khôi phục stream,
ghép tên tham chiếu, nhãn dữ liệu mẫu, tìm kiếm/lọc/xem chi tiết và bố cục mobile.

Kết quả kiểm tra ngày 20/10/2026:

- Phân tích tĩnh toàn dự án: không có vấn đề.
- Bộ test admin + đăng nhập/phân quyền: 8/8 vượt qua.
- Toàn bộ test: 232 vượt qua, 1 lỗi ở `patient_home_test.dart`, trường hợp
  `Patient home supports small screens, search and navigation` (overflow và
  không tìm thấy nhãn `CHƯA CÓ THÔNG BÁO`). Chạy lại riêng với trang admin gốc
  tại HEAD vẫn gặp cùng lỗi; chưa sửa vì ngoài phạm vi admin.
- Ảnh render kiểm tra bố cục ở 1440×1000 và 390×844 được tạo từ repository giả
  của widget test tại `build/admin-preview/`, không phải ảnh chụp dữ liệu production.
