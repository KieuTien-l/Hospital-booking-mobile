# NỘI DUNG BÁO CÁO ĐỒ ÁN CUỐI KỲ

## Ứng dụng đặt lịch khám bệnh HealWay

> Bản nội dung này bám theo yêu cầu nộp của học phần Lập trình trên thiết bị di động ECMP177: tập trung vào sản phẩm đã làm, công nghệ, chức năng, ảnh minh hoạ và kết quả thực nghiệm. Các chỗ trong ngoặc vuông cần được nhóm cập nhật trước khi nộp.

---

## 1. Trang bìa

**BỘ GIÁO DỤC VÀ ĐÀO TẠO**  
**[TÊN TRƯỜNG]**  
**[TÊN KHOA/VIỆN]**

**BÁO CÁO ĐỒ ÁN CUỐI KỲ**  
**HỌC PHẦN: LẬP TRÌNH TRÊN THIẾT BỊ DI ĐỘNG (ECMP177)**

**ĐỀ TÀI: ỨNG DỤNG ĐẶT LỊCH KHÁM BỆNH HEALWAY**

| Thành viên thực hiện | MSSV | Lớp |
| --- | --- | --- |
| [Họ tên thành viên 1] | [MSSV] | [Lớp] |
| [Họ tên thành viên 2] | [MSSV] | [Lớp] |
| [Bổ sung nếu có] | [MSSV] | [Lớp] |

Giảng viên phụ trách: **[Họ tên giảng viên]**  
Nhóm: **[Số nhóm]**  
Học kỳ: **[Học kỳ] - Năm học [20xx-20xx]**  
TP. Hồ Chí Minh, tháng [..] năm [20..]

---

## 2. Kết quả thực nghiệm

### 2.1. Tổng hợp công nghệ, chức năng và liên kết dự án

#### a. Tổng quan sản phẩm

HealWay là ứng dụng di động hỗ trợ đặt lịch khám với ba vai trò: bệnh nhân, bác sĩ và quản trị viên. Phần bệnh nhân được xây dựng trên Flutter và Firebase, gồm xác thực, hồ sơ bệnh nhân, tra cứu chuyên khoa/bác sĩ, chọn ca, đặt/hủy/đổi lịch, thông báo, phản hồi, lịch sử thanh toán, hồ sơ sức khỏe, kết quả cận lâm sàng và hình ảnh y tế. Ứng dụng cũng có giao diện bác sĩ và quản trị. Các tác vụ bác sĩ, thao tác ghi của quản trị viên, PayOS và chatbot cần dịch vụ backend hoặc biến môi trường phù hợp để hoạt động trên môi trường thật.

Liên kết Git công khai: **[DÁN LINK GITHUB/GITLAB CỦA NHÓM VÀO ĐÂY]**

#### b. Công nghệ và thư viện chính

| Thành phần | Công nghệ/thư viện | Mục đích sử dụng trong HealWay |
| --- | --- | --- |
| Ứng dụng di động | Flutter, Dart | Xây dựng giao diện đa nền tảng và luồng nghiệp vụ cho ứng dụng. |
| Giao diện | Material Design, Be Vietnam Pro, Font Awesome | Tạo giao diện, biểu tượng và phông chữ tiếng Việt nhất quán. |
| Xác thực | Firebase Authentication | Đăng ký, đăng nhập, đăng xuất, gửi email đặt lại mật khẩu và quản lý phiên người dùng. |
| Cơ sở dữ liệu | Cloud Firestore | Lưu tài khoản, hồ sơ bệnh nhân, bác sĩ, chuyên khoa, lịch làm việc, ca khám, lịch hẹn, thông báo, phản hồi và dữ liệu nghiệp vụ. |
| Phân quyền | Firebase Authentication kết hợp Firestore Security Rules | Kiểm soát quyền của bệnh nhân, bác sĩ và quản trị viên theo tài khoản đang đăng nhập. |
| Quản lý trạng thái | Provider, ChangeNotifier | Cập nhật trạng thái đăng nhập, đặt lịch, hồ sơ, thông báo, thanh toán và các màn hình quản trị. |
| Backend/API | Firebase Cloud Functions, Cloudflare Workers, HTTP | Xử lý các thao tác cần backend tin cậy như lệnh quản trị, nghiệp vụ bác sĩ, chatbot và tích hợp dịch vụ ngoài. |
| Thanh toán | PayOS, qr_flutter, url_launcher | Tạo phiên thanh toán, hiển thị mã QR/mở trang PayOS và tra cứu trạng thái thanh toán. |
| Lưu cục bộ | SharedPreferences | Lưu trạng thái đã xem phần giới thiệu ứng dụng. |
| Kiểm thử | flutter_test, Firestore Emulator, Node.js test | Kiểm thử widget/controller, transaction đặt lịch và các quy tắc truy cập Firestore. |

#### c. Tổng hợp chức năng

Ký hiệu trạng thái trong bảng được xác định sau khi đối chiếu mã nguồn, không suy diễn từ giao diện: **Đã triển khai trong mã nguồn** là có màn hình và logic tương ứng; **Cần cấu hình/hạ tầng** là có client hoặc giao diện nhưng phải triển khai Firebase/Worker/PayOS để chạy thật; **Chưa xác minh chạy thật** là không được mô tả như kết quả đã nghiệm thu.

| STT | Phân quyền/Module | Chức năng | Trạng thái |
| --- | --- | --- | --- |
| 1 | Chung | Màn hình khởi động và hướng dẫn sử dụng lần đầu | Đã triển khai trong mã nguồn |
| 2 | Tài khoản | Đăng ký bệnh nhân; tạo tài khoản Firebase Auth cùng bản ghi tài khoản và hồ sơ bệnh nhân trên Firestore | Đã triển khai trong mã nguồn; cần Firebase để chạy thật |
| 3 | Tài khoản | Đăng nhập, đăng xuất và điều hướng theo vai trò bệnh nhân/bác sĩ/admin | Đã triển khai trong mã nguồn; cần dữ liệu vai trò thật |
| 4 | Tài khoản | Gửi email đặt lại mật khẩu | Đã triển khai trong mã nguồn; cần Firebase Auth |
| 5 | Tài khoản | Chặn truy cập khi tài khoản có trạng thái khóa/không hoạt động | Đã triển khai trong mã nguồn |
| 6 | Bệnh nhân | Tạo, xem và cập nhật hồ sơ bệnh nhân | Đã triển khai trong mã nguồn; cần Firestore |
| 7 | Bệnh nhân | Xem chuyên khoa, thông tin bác sĩ và lịch trống | Đã triển khai trong mã nguồn; cần dữ liệu Firestore |
| 8 | Bệnh nhân | Chọn ngày, bác sĩ và ca khám còn chỗ | Đã triển khai trong mã nguồn; màn lịch có chế độ minh họa khi không dùng dữ liệu thật |
| 9 | Bệnh nhân | Xác nhận đặt khám; kiểm tra lại lịch/ca/bác sĩ/hồ sơ và sức chứa trong transaction | Đã triển khai trong mã nguồn; cần Firestore và Rules đã deploy |
| 10 | Bệnh nhân | Xem lịch sử/chi tiết lịch hẹn, hủy lịch và đổi ca | Đã triển khai trong mã nguồn; cần Firestore |
| 11 | Bệnh nhân | Xem, lọc, mở chi tiết, đánh dấu đã đọc/đọc tất cả thông báo | Đã triển khai trong mã nguồn; cần Firestore |
| 12 | Bệnh nhân | Gửi phản hồi và xem lịch sử phản hồi | Đã triển khai trong mã nguồn; không khẳng định đã có câu trả lời admin nếu chưa chạy backend thật |
| 13 | Bệnh nhân | Xem hồ sơ sức khỏe, kết quả cận lâm sàng và mục hình ảnh y tế | Đã triển khai màn hình/nguồn dữ liệu trong mã nguồn; cần dữ liệu Firestore |
| 14 | Bệnh nhân | Xem lịch sử thanh toán; tạo/tra cứu/hủy liên kết PayOS, QR và trang thanh toán | Đã triển khai trong mã nguồn; khi triển khai môi trường thực tế cần cấu hình Worker/URL HTTPS và PayOS webhook |
| 15 | Bệnh nhân | Chatbot hỗ trợ tra cứu và lưu lịch sử trò chuyện | Đã triển khai trong mã nguồn; chatbot gọi Worker qua HTTPS và cần cấu hình endpoint khi triển khai môi trường thực tế |
| 16 | Bác sĩ | Điều hướng vào không gian làm việc theo vai trò bác sĩ | Đã triển khai giao diện điều hướng |
| 17 | Bác sĩ | Xem lịch, ca và lịch hẹn theo ngày | Có client HTTP và giao diện; bản debug mặc định dùng dữ liệu minh họa, bản phát hành cần `DOCTOR_API_BASE_URL` |
| 18 | Bác sĩ | Lập/sửa hồ sơ khám và kết quả cận lâm sàng cho lịch được phân công | Có client HTTP và giao diện; cần backend bác sĩ, chưa xác minh chạy thật |
| 19 | Bác sĩ | Xem/gửi báo cáo nghiệp vụ | Có client HTTP và giao diện; cần backend bác sĩ, chưa xác minh chạy thật |
| 20 | Quản trị viên | Dashboard và tra cứu các collection nghiệp vụ | Đã triển khai giao diện/đọc dữ liệu; có thể hiển thị dữ liệu DEMO khi nguồn thật lỗi |
| 21 | Quản trị viên | Thêm/sửa/quản lý bác sĩ, chuyên khoa, bệnh nhân và tài khoản | Cần Worker/Cloud Function quản trị và cấu hình `ADMIN_COMMAND_BASE_URL`; chưa xác minh chạy thật |
| 22 | Quản trị viên | Điều hành lịch làm việc, ca khám và lịch hẹn | Cần Worker/Cloud Function quản trị; chưa xác minh chạy thật |
| 23 | Quản trị viên | Thông báo, phản hồi, thanh toán, hoàn tiền, cấu hình và báo cáo | Có giao diện/lệnh client; cần backend quản trị, chưa xác minh chạy thật |
| 24 | Hệ thống | Quy tắc Firestore giới hạn dữ liệu theo vai trò, chủ sở hữu và phân công | Có rule và kiểm thử trong mã nguồn; cần deploy để xác nhận môi trường thật |

**Lưu ý khi nộp:** Chỉ đổi các trạng thái “cần cấu hình/chưa xác minh chạy thật” thành “đã chạy thật” khi nhóm có ảnh chạy cùng log/kết quả kiểm thử trên chính Firebase/Worker/PayOS của nhóm. Không dùng ảnh dữ liệu DEMO làm bằng chứng cho dữ liệu bệnh viện thật.

### 2.2. Minh hoạ chi tiết các chức năng

> Khi dán sang Word, thay mỗi dòng **[Chèn Hình ...]** bằng ảnh chụp thật từ ứng dụng. Dưới ảnh giữ nguyên hoặc chỉnh nhẹ phần mô tả tương ứng. Mỗi ảnh cần có chú thích theo mẫu: “Hình n. [Tên màn hình]”.

#### 2.2.1. Đăng ký, đăng nhập và khôi phục mật khẩu

**[Chèn Hình 1. Màn hình đăng nhập và đăng ký HealWay]**

Người dùng mới nhập họ tên, số điện thoại, email và mật khẩu để tạo tài khoản. Mã nguồn gọi Firebase Authentication để tạo tài khoản, sau đó ghi đồng thời bản ghi tài khoản và hồ sơ bệnh nhân vào Firestore. Khi đăng nhập, ứng dụng đọc hồ sơ tài khoản để điều hướng theo vai trò bệnh nhân, bác sĩ hoặc quản trị viên; tài khoản không hoạt động được đưa đến màn hình khóa. Chức năng quên mật khẩu gọi API gửi email đặt lại mật khẩu của Firebase. Khi minh họa, nhóm cần dùng tài khoản thử nghiệm của chính nhóm và chụp rõ thông báo thành công/thất bại; không dùng dữ liệu cá nhân thật.

#### 2.2.2. Quản lý hồ sơ bệnh nhân

**[Chèn Hình 2. Màn hình danh sách và chi tiết hồ sơ bệnh nhân]**

Người dùng có thể tạo hồ sơ bệnh nhân, lựa chọn hồ sơ khi đặt khám và cập nhật thông tin hành chính cần thiết. Thông tin hồ sơ được tách khỏi dữ liệu tài khoản để hỗ trợ quản lý thông tin khám chữa bệnh. Việc chỉnh sửa thông tin giúp dữ liệu dùng trong lịch hẹn chính xác hơn, đồng thời người dùng có thể xem lịch sử đặt khám, hồ sơ khám và kết quả cận lâm sàng theo hồ sơ đã chọn.

#### 2.2.3. Tra cứu chuyên khoa và bác sĩ

**[Chèn Hình 3. Màn hình danh sách chuyên khoa và thông tin bác sĩ]**

Ứng dụng hiển thị danh sách chuyên khoa để người dùng bắt đầu nhu cầu đặt khám. Sau khi chọn chuyên khoa, người dùng xem được các bác sĩ phù hợp và thông tin cơ bản của bác sĩ trước khi chọn khám. Cách tổ chức này giúp người dùng thu hẹp lựa chọn từ chuyên khoa đến bác sĩ, thay vì phải tìm thủ công trong toàn bộ danh sách.

#### 2.2.4. Đặt lịch khám theo ca còn trống

**[Chèn Hình 4. Các bước chọn chuyên khoa, bác sĩ, ngày và ca khám]**

Người dùng lần lượt chọn chuyên khoa, ngày khám, bác sĩ và ca khám. Khi kết nối dữ liệu thật, ứng dụng tải bác sĩ theo chuyên khoa và chỉ đưa vào luồng đặt khám những ca còn khả dụng; màn hình chọn ngày cũng có chế độ lịch minh họa phục vụ giao diện/test. Ở bước xác nhận, ứng dụng tổng hợp thông tin bệnh nhân, bác sĩ, thời gian và phí khám. Logic `createAppointment` dùng transaction Firestore để kiểm tra lịch làm việc, ca khám, bác sĩ, hồ sơ bệnh nhân và sức chứa trước khi tạo lịch hẹn, cập nhật số chỗ và tạo thông báo. Nhóm chỉ nên mô tả đây là “kết quả chạy thực tế” sau khi đã kiểm tra trên Firestore của nhóm.

#### 2.2.5. Theo dõi, hủy và chuyển lịch hẹn

**[Chèn Hình 5. Màn hình lịch sử và chi tiết lịch hẹn]**

Người dùng xem được danh sách lịch hẹn, trạng thái và thông tin chi tiết của từng lần khám. Từ màn hình chi tiết, người dùng có thể thực hiện hủy hoặc chuyển lịch khi điều kiện nghiệp vụ cho phép. Khi thay đổi lịch, hệ thống dùng transaction để trả chỗ ở ca cũ, giữ chỗ ở ca mới và cập nhật thông tin lịch hẹn, nhờ đó hạn chế lỗi số lượng chỗ không đồng bộ.

#### 2.2.6. Thanh toán lịch hẹn qua PayOS

**[Chèn Hình 6. Màn hình tạo phiên thanh toán và mã QR PayOS]**

**Hình 6a** thể hiện lịch sử thanh toán; **Hình 6b** thể hiện luồng tạo phiên PayOS, số tiền, mã giao dịch, QR, mở trang thanh toán và kiểm tra trạng thái. HealWay đã có màn hình tạo phiên thanh toán, hiển thị số tiền/mã giao dịch/mã QR, mở liên kết PayOS, kiểm tra trạng thái và hủy liên kết khi còn chờ thanh toán. Client sử dụng `PAYMENT_WORKER_BASE_URL` hoặc `ADMIN_COMMAND_BASE_URL` để trao đổi với backend HTTPS. Khi triển khai môi trường thực tế, trạng thái thanh toán được xác nhận bởi backend/PayOS và webhook; ảnh minh hoạ trong báo cáo được chú thích DEMO nếu đang dùng dữ liệu mẫu.

#### 2.2.7. Thông báo, phản hồi và chatbot hỗ trợ

**[Chèn Hình 7. Màn hình thông báo, phản hồi khách hàng và chatbot]**

Thông báo được lấy theo `patientId`; người dùng có thể lọc tất cả/chưa đọc, mở chi tiết, đánh dấu từng thông báo hoặc đọc tất cả. **Hình 7a là chức năng phản hồi ý kiến khách hàng:** người dùng chọn loại phản hồi, mức độ hài lòng, nhập tiêu đề và nội dung góp ý; lịch sử phản hồi được đọc từ Firestore. **Hình 7b là chatbot, một chức năng riêng:** chatbot có màn hình hội thoại, lưu lịch sử trao đổi và gọi Worker qua HTTPS để hỗ trợ người dùng trong thao tác đặt khám/tra cứu thông tin cơ bản. Nội dung chatbot được giới hạn hỗ trợ sức khỏe phổ thông, không chẩn đoán, kê đơn hoặc xử lý cấp cứu.

#### 2.2.8. Xem hồ sơ khám và kết quả cận lâm sàng

**[Chèn Hình 8. Màn hình hồ sơ khám và kết quả cận lâm sàng]**

Người dùng có thể xem các hồ sơ khám đã lập, kết quả cận lâm sàng và hình ảnh liên quan theo hồ sơ bệnh nhân. Thông tin được trình bày theo từng lần khám để người dùng theo dõi quá trình chăm sóc sức khỏe. Ứng dụng chỉ hiển thị dữ liệu thuộc hồ sơ có quyền truy cập, phù hợp với phân quyền của hệ thống.

#### 2.2.9. Không gian làm việc của bác sĩ

**[Chèn Hình 9. Màn hình lịch làm việc của bác sĩ]**

Ứng dụng có route và không gian giao diện riêng cho bác sĩ. Khi được truyền `DOCTOR_API_BASE_URL`, client có thể gọi backend HTTPS để tải lịch làm việc, ca và lịch hẹn theo ngày; client chỉ nhận projection thông tin bệnh nhân cần thiết cho lịch được phân công. Trong cấu hình debug mặc định, màn hình dùng dữ liệu minh họa; nếu thiếu endpoint ở bản phát hành, ứng dụng hiện lỗi cấu hình thay vì coi dữ liệu minh họa là dữ liệu thật.

**[Chèn Hình 10. Màn hình bác sĩ ghi hồ sơ khám và kết quả cận lâm sàng]**

Giao diện có form lập/cập nhật hồ sơ khám và kết quả cận lâm sàng. Client gửi yêu cầu tới API bác sĩ kèm mã chống gửi trùng; backend dự kiến xác minh bác sĩ, lịch hẹn và trạng thái trước khi ghi. Đây là phần **có mã giao diện/client nhưng chưa được chứng minh là chạy thật trong cấu hình hiện tại**, vì dự án không đặt sẵn `DOCTOR_API_BASE_URL`; chỉ chèn ảnh thao tác lưu thành công khi nhóm đã triển khai API bác sĩ.

#### 2.2.10. Quản trị vận hành bệnh viện

**[Chèn Hình 11. Dashboard quản trị HealWay]**

Dashboard quản trị có phần tổng quan, lọc dữ liệu và liên kết đến các nhóm lịch hẹn, bác sĩ, bệnh nhân, chuyên khoa, lịch làm việc, ca khám, phản hồi, tài khoản, thanh toán và báo cáo. Giao diện có cơ chế báo rõ lỗi truy cập; chỉ khi người dùng chủ động chọn xem DEMO mới hiển thị dữ liệu minh họa. Vì vậy, ảnh demo phải được chú thích là “DEMO”, không được dùng để khẳng định số liệu vận hành thật.

**[Chèn Hình 12. Màn hình quản lý bác sĩ, chuyên khoa, lịch làm việc và ca khám]**

Mã nguồn có form và lớp lệnh quản trị cho bác sĩ, chuyên khoa, bệnh nhân, tài khoản, lịch làm việc, ca khám và lịch hẹn. Các lệnh ghi không ghi trực tiếp từ Flutter mà gọi Worker/Cloud Function có xác thực. Do project cần `ADMIN_COMMAND_BASE_URL` hoặc Firebase Function đã deploy, báo cáo chỉ nên nói “đã xây dựng giao diện và client command” nếu chưa có ảnh kiểm thử trên backend của nhóm.

**[Chèn Hình 13. Màn hình quản lý lịch hẹn, thông báo và phản hồi]**

Giao diện quản trị có menu thao tác cho lịch hẹn, thông báo, phản hồi, thanh toán, hoàn tiền, cấu hình và báo cáo. Các ràng buộc như không giảm sức chứa dưới số chỗ đã giữ hoặc không xóa lịch hẹn có lịch sử nằm trong thiết kế backend/command. Vì các thao tác này phụ thuộc backend quản trị, chỉ liệt kê là kết quả đã hoàn thành sau khi chạy với tài khoản admin thử nghiệm và lưu được biên nhận/kết quả tương ứng.

#### 2.2.11. Phân quyền và bảo vệ dữ liệu

**[Chèn Hình 14. Màn hình khác nhau theo vai trò bệnh nhân, bác sĩ và quản trị viên]**

HealWay phân tách giao diện và dữ liệu theo ba vai trò. Bệnh nhân chỉ xem/chỉnh sửa dữ liệu thuộc hồ sơ và lịch hẹn của mình; bác sĩ chỉ xem dữ liệu gắn với lịch hẹn được phân công; quản trị viên có quyền điều hành theo quy định hệ thống. Firestore Security Rules được dùng cùng với trạng thái tài khoản để từ chối các truy cập trái quyền ngay tại tầng dữ liệu.

### 2.3. Kết quả đối chiếu và kiểm thử cần đưa vào báo cáo

Qua lần đối chiếu mã nguồn, nhóm có thể khẳng định sản phẩm đã có các lớp giao diện, repository/controller và datasource cho các luồng bệnh nhân chính: xác thực, hồ sơ, chuyên khoa/bác sĩ, lịch/ca, đặt-hủy-đổi lịch, thông báo, phản hồi, dữ liệu hồ sơ sức khỏe và kết quả cận lâm sàng. Luồng đặt lịch có transaction ở phía Firestore để kiểm tra các liên kết và sức chứa trước khi ghi dữ liệu. Các rule Firestore cũng có logic phân quyền theo bệnh nhân, bác sĩ và quản trị viên.

Tuy nhiên, mã nguồn **không tự là bằng chứng hệ thống đang chạy trên môi trường thật**. Những nội dung sau phải được nhóm kiểm tra và chụp minh chứng trước khi ghi là “đã hoàn thành”:

| Hạng mục | Minh chứng tối thiểu cần có trước khi nộp |
| --- | --- |
| Firebase Auth và Firestore | Ảnh đăng ký/đăng nhập bằng tài khoản test; ảnh bản ghi tài khoản/hồ sơ/lịch hẹn hoặc log Firebase Emulator. |
| Đặt, hủy và đổi lịch | Ảnh trước/sau thao tác; kiểm tra số chỗ ca khám thay đổi đúng; không dùng lịch minh họa. |
| Firestore Rules | Kết quả chạy test rule hoặc kiểm tra bằng ba tài khoản thử nghiệm patient/doctor/admin. |
| PayOS | Ảnh tạo link/QR và trạng thái từ Worker/PayOS; chỉ đánh dấu thành công sau webhook/xác nhận backend. |
| Chatbot | Ảnh câu hỏi, phản hồi từ Worker và trạng thái lỗi khi không kết nối; không đưa tuyên bố chẩn đoán y tế. |
| Backend bác sĩ | Ảnh tải lịch bác sĩ và lưu hồ sơ/kết quả thành công với `DOCTOR_API_BASE_URL` đã cấu hình. |
| Backend quản trị | Ảnh thao tác ghi thành công với `ADMIN_COMMAND_BASE_URL` hoặc Firebase Function đã deploy. |
| Git công khai | URL repository mở được ở chế độ public, đúng phiên bản mã nguồn dùng để chụp ảnh/kiểm thử. |

**Đoạn kết quả kiểm thử chỉ dùng sau khi đã chạy:** “Nhóm đã chạy `flutter analyze`, `flutter test` và các kiểm thử backend/rule phù hợp với cấu hình của nhóm. Các luồng được kiểm tra gồm xác thực, đặt-hủy-đổi lịch, kiểm tra sức chứa ca khám, thông báo và phân quyền. Kết quả chi tiết được lưu ở [bổ sung ảnh chụp terminal hoặc log].” Không ghi số lượng test PASS nếu không có log của lần chạy cuối.

---

## 3. Kết luận

HealWay đã xây dựng các luồng bệnh nhân cốt lõi gồm xác thực, hồ sơ, tra cứu chuyên khoa/bác sĩ, chọn lịch và ca, đặt-hủy-đổi lịch, thông báo, phản hồi, dữ liệu hồ sơ sức khỏe và kết quả cận lâm sàng. Dự án còn có giao diện và lớp client cho bác sĩ, quản trị, thanh toán PayOS và chatbot. Điểm kỹ thuật nổi bật là transaction Firestore cho đặt lịch, các rule phân quyền theo vai trò và chủ sở hữu dữ liệu, cùng định hướng đưa thao tác nhạy cảm về backend tin cậy.

PayOS, chatbot, backend bác sĩ và các lệnh ghi của quản trị viên đã có giao diện và lớp tích hợp tương ứng. Khi triển khai môi trường thực tế, các phần này cần Cloud Function/Cloudflare Worker, URL HTTPS, biến môi trường và webhook phù hợp. Trước khi nộp, nhóm cần kiểm tra trên Firebase của nhóm bằng ba tài khoản test (patient/doctor/admin), ghi rõ phần nào là DEMO và chỉ giữ ảnh của các luồng đã chạy thật.

Trong tương lai, nhóm có thể hoàn thiện luồng thanh toán và đối soát tự động, bổ sung nhắc lịch/push notification, triển khai phân trang và tổng hợp báo cáo ở backend khi dữ liệu lớn, mở rộng chatbot bằng kho tri thức được kiểm duyệt, đồng thời tăng cường kiểm thử tích hợp và kiểm thử bảo mật trên môi trường triển khai thật.

---

## Phụ lục - Danh sách ảnh cần chụp trước khi nộp

1. Đăng nhập và đăng ký.
2. Hồ sơ bệnh nhân.
3. Chuyên khoa/danh sách bác sĩ.
4. Chọn ngày, ca khám và trang xem lại lịch hẹn.
5. Lịch sử/chi tiết lịch hẹn.
6. Phiên thanh toán PayOS (nếu đã cấu hình).
7. Thông báo, phản hồi và chatbot (nếu đã cấu hình).
8. Hồ sơ khám/kết quả cận lâm sàng.
9. Lịch làm việc bác sĩ.
10. Bác sĩ lập hồ sơ khám/kết quả CLS (nếu đã cấu hình API bác sĩ).
11. Dashboard quản trị.
12. Quản lý bác sĩ/chuyên khoa/lịch làm việc/ca khám.
13. Quản lý lịch hẹn, thông báo hoặc phản hồi.
14. So sánh giao diện của bệnh nhân, bác sĩ và quản trị viên.

Không đưa vào báo cáo các phần không được yêu cầu như lời cảm ơn, cơ sở lý thuyết dài, ERD, phân tích thiết kế cơ sở dữ liệu hay diễn giải source code chi tiết.
