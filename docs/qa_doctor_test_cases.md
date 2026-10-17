# QA-01 — Test case Doctor

Ngày lập: 17/10/2026
Phạm vi: dashboard bác sĩ, lịch làm việc, khung giờ khám và chi tiết ca khám.

| ID | Kịch bản | Bước chính | Kết quả mong đợi | Tự động hóa |
| --- | --- | --- | --- | --- |
| DOC-01 | Mở dashboard với tài khoản bác sĩ | Đăng nhập tài khoản có vai trò `doctor` | Hiện lời chào bác sĩ và ba chỉ số Đã đặt/Đã khám/Chờ khám | `doctor_home_page_test.dart` |
| DOC-02 | Tải lịch theo bác sĩ và ngày được chọn | Chọn một ngày, dashboard tải lịch làm việc | Chỉ lịch của bác sĩ đăng nhập và đúng ngày được hiển thị | `doctor_dashboard_controller_test.dart` |
| DOC-03 | Hiển thị trạng thái tải/rỗng/lỗi | Trả về lần lượt loading, empty, error từ dashboard | Màn hình có thông điệp đúng trạng thái, không có thao tác sai | `doctor_home_page_test.dart` |
| DOC-04 | Xem ca khám theo buổi | Có các `TimeSlot` buổi sáng/chiều | Ca được gom theo ngày và buổi; giờ tăng dần; desktop/mobile không tràn | `doctor_home_page_test.dart` |
| DOC-05 | Nhận biết chỗ trống và ca đầy | Đặt `bookedCount` bằng hoặc nhỏ hơn `capacity` | Ca đầy hiện “Đã đặt hết”; ca còn chỗ hiện màu và nhãn phù hợp | `doctor_home_page_test.dart` |
| DOC-06 | Mở chi tiết một khung giờ | Nhấn vào khung giờ bất kỳ | Mở “Chi tiết ca khám”, đúng ngày/giờ/sức chứa và danh sách lịch của khung giờ đó | `doctor_slot_details_page_test.dart` |
| DOC-07 | Lọc danh sách bệnh nhân trong ca | Nhập tên/mã bệnh nhân; chọn Tất cả/Chờ khám/Đã khám | Danh sách lọc đúng theo tên, mã và trạng thái, số thứ tự vẫn tăng dần | `doctor_slot_details_page_test.dart` |
| DOC-08 | Bảo vệ dữ liệu bệnh nhân | Nạp lịch/hẹn khác bác sĩ hoặc khác khung giờ | Không hiển thị dữ liệu không thuộc bác sĩ/khung giờ đang xem | `doctor_dashboard_controller_test.dart`, `doctor_slot_details_page_test.dart` |
| DOC-09 | Chọn ngày và khả năng đáp ứng | Dùng date picker, thanh ngày; thử màn 320px và text scale 2x | Ngày được giữ khi đổi tab; bố cục không overflow | `doctor_home_page_test.dart` |

## Dữ liệu kiểm thử

- Preview độc lập dùng dữ liệu mẫu được gắn nhãn “Dữ liệu mẫu”.
- Luồng thực dùng `DoctorDashboardController`, lọc theo tài khoản bác sĩ đã xác thực, lịch làm việc và `TimeSlot` tương ứng.
- Không dùng tên bệnh nhân từ Firestore trong danh sách dashboard thực; tên hiển thị là định danh an toàn khi nguồn không cung cấp dữ liệu đã được cấp quyền.
