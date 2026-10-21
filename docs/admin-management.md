# Quản trị HealWay — triển khai ngày 21/10/2026

Đây là phần bổ sung nghiệp vụ sau đợt làm giao diện. Các mô tả “chỉ đọc”,
“chưa sửa rules” và “cấu hình DEMO” trong lịch sử `admin-ui-data-sources.md`
chỉ áp dụng cho đợt giao diện trước đó.

## Các thao tác đã có trong mã nguồn

| Mục | Admin thao tác được | Giới hạn bảo toàn dữ liệu |
| --- | --- | --- |
| Bác sĩ | Tạo hồ sơ kèm tài khoản đăng nhập; sửa thông tin cá nhân/chuyên môn; gửi email thiết lập mật khẩu; ngừng/mở nhận lịch mới | Email đăng nhập tách khỏi email liên hệ. Không đổi UID hay vai trò qua form hồ sơ. Chỉ xóa hồ sơ chưa có dữ liệu liên quan; khóa tài khoản ứng dụng liên kết và giữ danh tính Auth |
| Chuyên khoa | Thêm, sửa, bật/tắt, xóa khi chưa sử dụng | Có bác sĩ/lịch hẹn liên quan thì không xóa |
| Bệnh nhân | Thêm hồ sơ gắn tài khoản patient hiện có; sửa thông tin hành chính; lưu trữ/khôi phục | Không xóa lịch sử khám hoặc sửa nội dung chuyên môn |
| Lịch làm việc | Tạo và tự sinh ca, lặp cùng thứ tối đa 8 tuần, sao chép sang ngày khác; sửa lịch chưa có lịch sử đặt; bật/tắt; xóa lịch chưa sử dụng kèm các ca trống | Kiểm tra trùng giờ, giờ quá khứ, Chủ nhật và chiều thứ bảy theo quy tắc hiện có. Giữ các lịch hẹn đã đặt khi tắt lịch |
| Ca khám | Thêm, sửa, khóa/mở nhận đặt; xóa ca chưa sử dụng | Sức chứa không thấp hơn số chỗ đang giữ; không đổi giờ ca đã có lịch sử |
| Lịch hẹn | Đặt hộ, xác nhận, hủy, ghi nhận vắng sau giờ khám, chuyển ca; ghi chú nội bộ | Không xóa lịch hẹn, tự đánh dấu hoàn thành hoặc mở lại trạng thái kết thúc. Giữ/trả chỗ theo `peopleCount` trong transaction; giữ nguyên phí đã chốt khi chuyển ca |
| Tài khoản | Khóa/mở quyền truy cập ứng dụng; chỉnh vai trò khi chưa gắn hồ sơ | Chặn tự khóa/hạ quyền bản thân; không đổi vai trò tài khoản đã gắn hồ sơ. Khóa ứng dụng bằng `TAI_KHOAN.isActive`, không tuyên bố xóa hay vô hiệu hóa danh tính Firebase Auth |
| Phản hồi | Tiếp nhận, phân công admin, đổi trạng thái, trả lời | Không sửa đánh giá/nội dung gốc. Patient gửi phản hồi thật và xem trả lời trong lịch sử |
| Thông báo | Soạn/sửa/xóa nháp, xem trước trong chi tiết và gửi đến hồ sơ bệnh nhân | Gửi trong app tới tài khoản sở hữu hồ sơ; không phải push hoặc email hàng loạt. Bản đã gửi không sửa/xóa; patient chỉ đánh dấu đã đọc |
| Thanh toán | Ghi nhận đối soát, ghi chú và tạo yêu cầu hoàn tiền | Giữ nguyên số tiền/trạng thái thanh toán thực tế. `REQUESTED` chỉ là yêu cầu, chưa hoàn tiền qua cổng thanh toán |
| Cấu hình | Lưu tên cơ sở, thông tin hỗ trợ, thời lượng và sức chứa mặc định khi admin tạo lịch | Chưa điều khiển chính sách đặt/hủy/nhắc lịch của patient |
| Báo cáo | Lọc khoảng ngày, tổng hợp lịch khám theo bác sĩ, tổng tiền thực thu theo thời điểm thanh toán; sao chép CSV | Dữ liệu nguồn là bản ghi Firestore đã tải; CSV đưa vào clipboard, không tạo file tải xuống. Không suy diễn doanh thu từ lịch chưa thanh toán |
| Nhật ký/cấp tài khoản/hoàn tiền | Tra cứu kết quả và các trường hợp cần xử lý | Không cho sửa nhật ký hoặc giả lập hoàn tất quy trình bên ngoài |
| Hồ sơ sức khỏe, CLS, AI | Tra cứu | Không cung cấp thao tác chỉnh/xóa nội dung chuyên môn |

Các nút ghi không xuất hiện trên bản ghi DEMO cục bộ. Form giữ dữ liệu khi lỗi,
yêu cầu lý do thao tác, khóa nút lúc đang lưu và giữ mã yêu cầu cho lần thử lại
cùng nội dung. Máy chủ kiểm tra lại quyền/trạng thái mới nhất; ghi thay đổi,
nhật ký và biên nhận chống trùng trong cùng transaction. Ghi chú nội bộ lưu
riêng ở `ADMIN_NOTES`, không nằm trong tài liệu lịch hẹn patient/doctor đọc.

## Quy trình bác sĩ

1. Admin chọn **Bác sĩ → Thêm bác sĩ & tài khoản**, nhập email đăng nhập cùng hồ sơ.
2. Cloud Function tạo Auth user rồi gắn `TAI_KHOAN` và `BAC_SI` bằng UID.
   Không đăng nhập thay bác sĩ trên thiết bị admin. Mật khẩu khởi tạo ngẫu nhiên
   không được hiển thị, lưu Firestore hoặc ghi nhật ký.
3. Sau khi tạo thành công có form riêng để admin xác nhận gửi email thiết lập
   mật khẩu bằng Firebase Auth. Có thể hủy bước gửi và gửi lại ở chi tiết.
   Nếu gửi email lỗi, tài khoản/hồ sơ vẫn được giữ, không tạo lại bác sĩ.
4. Bác sĩ đăng nhập và xem hồ sơ từ Firestore theo UID. Thông tin cá nhân và
   chuyên môn do admin quản lý; bác sĩ chỉ tự đổi/khôi phục mật khẩu.
5. Ngừng nhận lịch mới không khóa tài khoản, nên bác sĩ vẫn xem/xử lý lịch cũ.

## Các thành phần cần triển khai cùng bản app

Đợt làm mã nguồn này **chưa triển khai lên Firebase thật**, chưa tạo tài khoản
bác sĩ thật hoặc gửi email thực tế. Endpoint chưa có sẽ báo rõ trong ứng dụng.

- `functions/src/index.js`: callable `adminCommand`, region `asia-southeast1`, Node.js 22.
- `firestore.rules`: quyền đọc và ràng buộc patient/doctor; các thao tác admin
  ghi qua backend tin cậy thay vì cho phép client sửa tùy ý.
- `firestore.indexes.json`: truy vấn lịch bác sĩ, thông báo và phản hồi.
- Bản Flutter có gateway gọi Function bằng ID token của phiên hiện tại.

Sau khi kiểm tra project đích và cấu hình Firebase CLI, người vận hành thực hiện
từ thư mục gốc dự án:

```powershell
cd functions
npm ci
cd ..
firebase deploy --only functions:admin,firestore:rules,firestore:indexes --project <PROJECT_ID>
```

Chờ indexes sẵn sàng trước khi thử luồng thật. Chạy thử bằng admin đang hoạt động,
một tài khoản bác sĩ thử và một patient thử: tạo bác sĩ → gửi email → đăng nhập
bác sĩ → chỉnh hồ sơ từ admin → đặt/chuyển/hủy lịch → gửi/đọc thông báo và phản hồi.
Không chèn service account vào app. Backend dùng danh tính chạy Cloud Functions.

Tài khoản admin ban đầu cần được cấp bởi người vận hành tin cậy; giao diện không
cho một patient tự nâng quyền. Với hệ thống lớn, listener hiện đọc toàn collection
và phân trang phía UI; cần truy vấn phân trang/tổng hợp backend khi mở rộng dữ liệu.

## Khôi phục cấp tài khoản không hoàn tất

Auth và Firestore là hai dịch vụ riêng. `ADMIN_PROVISIONING` ghi trạng thái
`CREATING` → `AUTH_CREATED` → `READY`; lỗi đã thu hồi Auth user thành `FAILED`.
Chỉ cùng nội dung/mã yêu cầu/actor ở trạng thái `FAILED` mới được thử lại tự động.

Nếu mất xác nhận commit, backend đọc biên nhận trước khi thu hồi Auth user,
tránh xóa tài khoản đã cấp thành công. Trường hợp không xác minh/thu hồi được
được đánh dấu `NEEDS_RECOVERY` và giữ `authUserId` nếu có. Người vận hành cần
đối chiếu Auth user, `TAI_KHOAN`, `BAC_SI` và `ADMIN_COMMANDS`; hoàn tất liên kết
đúng UID hoặc thu hồi phần cấp dở. Không tạo yêu cầu mới hoặc gửi tài khoản khác
cho bác sĩ trước khi giải quyết trạng thái này. Giao diện chỉ tra cứu trường hợp
cần khôi phục; không có nút tự động sửa Auth/Firestore khi chưa rõ kết quả.

## Kiểm thử cục bộ

Kết quả xác minh ngày 21/10/2026: `flutter analyze` không có vấn đề;
toàn bộ 247 kiểm thử Flutter vượt qua, sau đó kiểm thử bổ sung form tạo bác sĩ
và menu thao tác ở màn 320 px/chữ 130% cũng vượt qua. Backend có 19 kiểm thử
policy/Auth/Firestore emulator vượt qua. Ảnh bố cục giả lập tại
`build/admin-preview/doctor-create-320.png` và `doctor-actions-320.png`.
Đã sửa overflow ở tiêu đề thông báo trên màn nhỏ và cập nhật nhãn rỗng cũ
trong kiểm thử patient; đây là lỗi đã có từ đợt kiểm tra trước.

```powershell
flutter analyze
flutter test
cd functions
npm test
npm run test:emulator
```

Emulator test chỉ dùng project demo `demo-healway-admin`, bắt buộc có biến môi
trường Auth/Firestore emulator và không truy cập production. Kiểm tra phân quyền,
đăng ký patient, hồ sơ bác sĩ chỉ đọc, cấp tài khoản/rollback/mất phản hồi,
chống đặt quá chỗ, hủy/chuyển lịch, chặn xóa lịch sử, nháp thông báo, phản hồi,
ghi chú nội bộ và yêu cầu hoàn tiền. Các widget test dùng repository/command giả.

Máy phát triển hiện dùng JRE 11 portable trong `build/admin-test-runtime` để chạy
Firestore emulator với Firebase CLI 14; Java 22/25 trên máy gặp lỗi loopback.
Runtime này chỉ là công cụ kiểm thử, không đóng gói vào app/backend. Với môi trường
khác, dùng Java tương thích bản Firebase CLI được khóa trong package-lock.

Tham khảo giao thức [Firebase callable](https://firebase.google.com/docs/functions/callable-reference),
[Admin Auth](https://firebase.google.com/docs/auth/admin/manage-users) và
[Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions).
