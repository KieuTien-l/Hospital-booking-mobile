# QA-04 — Báo cáo kiểm thử

Ngày chạy: 17/10/2026
Nhánh kiểm thử: `NgocVan`
Phạm vi: regression Patient, Doctor dashboard/lịch hẹn và Firestore security rules.

## Kết quả

| Hạng mục | Lệnh/nguồn | Kết quả |
| --- | --- | --- |
| Phân tích tĩnh | `dart analyze` | Không có lỗi mã nguồn |
| Regression Flutter | `flutter test --no-pub` | 244/244 test đạt |
| Doctor UI | `doctor_home_page_test.dart`, `doctor_slot_details_page_test.dart` | Đạt; kiểm tra bố cục mobile, khung giờ, chi tiết ca và trạng thái dữ liệu |
| Doctor controller | `doctor_dashboard_controller_test.dart` | Đạt; kiểm tra tải lịch, `TimeSlot` và thống kê |
| Đặt lịch an toàn | `appointment_booking_test.dart` | Đạt; kiểm tra giữ/chuyển/giải phóng chỗ bằng transaction |
| Firestore rules | `npm run test:firestore-rules` | 5/5 test đạt |

## Regression Patient

Các test Patient đã chạy trong full suite: đăng nhập, hồ sơ, lịch sử đặt lịch, hồ sơ sức khỏe, kết quả lâm sàng, ảnh chẩn đoán, thanh toán, trang chủ và điều hướng. Không phát hiện regression.

## Kết luận

- Không phát hiện lỗi chặn phát hành trong phạm vi tự động hóa hiện có.
- Dashboard Doctor dùng đúng bố cục ca khám theo ngày/buổi của KieuTien, đồng thời vẫn lấy lịch và `TimeSlot` từ luồng dữ liệu thật của NgocVan.
- Các ticket Jira `SCRUM-289` đến `SCRUM-292` không truy cập được từ Jira workspace đang kết nối, nên chưa thể chuyển trạng thái hoặc đính kèm báo cáo vào ticket.
