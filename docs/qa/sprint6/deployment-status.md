# Trạng thái triển khai và bàn giao Sprint 6

Cập nhật 25/10/2026 (Asia/Saigon). Đây là phần tiếp tục sau bộ QA tự động;
các probe và phiên Android ghi thời gian UTC trong evidence.

> Bản sửa bổ sung hiện **chỉ kiểm thử tự động/emulator** theo lựa chọn người dùng.
> [Chi tiết và bằng chứng mới](followup-2026-10-25.md): 349 Flutter, 42 Firebase
> và 3 Functions HTTP đạt. Rules bổ sung chưa triển khai production; APK mới cần
> Rules cùng phiên bản cho audit duyệt tài khoản và trang liên hệ.

| Hạng mục | Kết quả thực tế |
| --- | --- |
| GitHub `NgocVan` | Đã tích hợp mã qua kết nối GitHub, commit `2d10fa8e4f2572ecdd2a092a772b7f0312c519f4`. Báo cáo và evidence triển khai được bổ sung trong commit kế tiếp. |
| Đối chiếu source | Tree SHA của commit tích hợp là `9a1cf805b225a6206bea0217cef791ea2952fe66`, giống hệt commit local đã kiểm thử `c827974`. Lần bổ sung này chỉ cập nhật báo cáo, evidence và script đóng gói; không đổi mã ứng dụng/backend. |
| `QuocViet` | Giữ nguyên `706b872b0e307f5f4c075fad039e156a80f5e46f`; không ghi vào nhánh này. |
| Local | Đã đồng bộ `NgocVan` với GitHub; commit local trước đó còn ở `refs/codex/sprint6-local-snapshot`. |
| Firestore Rules | **Đã triển khai thành công** trên project `bookinghospitalapp`. CLI xác nhận compiled, uploaded, released và Deploy complete. |
| `adminCommand` | **Chưa triển khai**. Firebase CLI yêu cầu Blaze để bật Artifact Registry; người dùng đã chọn **giữ gói hiện tại, chưa triển khai Functions**. Không tự nâng cấp hoặc bật thanh toán. |
| Chatbot Worker mới | **Đã triển khai** lên Worker hiện có `healway-chatbot` trong account Việt sau khi làm mới OAuth nhận quyền mới. Version `424a04dd-8ee5-42b7-8ba8-14a50d3a04d8` đang phục vụ 100% lưu lượng. Giữ URL và secret `OPENAI_API_KEY` hiện có; không đọc/đổi giá trị secret. |
| APK | Đã cài thành công và cold start tới màn đăng nhập trên Pixel 7 emulator, Android 17/API 37; không thấy fatal error trong log app. Chưa nghiệm thu trên điện thoại thật hoặc luồng có đăng nhập. |
| Source ZIP | Đóng gói lại từ commit GitHub; `build/sprint6-handoff/manifest.json` ghi commit/checksum thực tế. Không chứa `.git` hoặc `node_modules`. |

## Kiểm tra chỉ đọc trên môi trường thật

Xem [deployment-smoke.json](evidence/deployment-smoke.json):

- Firestore `TAI_KHOAN`: truy cập không đăng nhập tới ID giả hợp lệ trả **403 PERMISSION_DENIED**.
- Firestore `LS_CHAT_AI`: truy cập không đăng nhập tới ID giả hợp lệ trả **403 PERMISSION_DENIED**.
- Endpoint chatbot hiện có: POST không có token trả **401**. Đây là endpoint đã có,
  **không chứng minh Worker mới đã được triển khai**.

Không đọc hồ sơ bệnh nhân thật, không ghi dữ liệu production và không gọi mô hình
AI trong các probe này. Hai URI thử đầu tiên dùng ID dành riêng của Firestore
nên trả 400; đã sửa URI và thực hiện lại bằng ID hợp lệ như evidence.

## Triển khai chatbot sau khi cấp quyền

- OAuth mới xác nhận account Việt `f1895a598232f4c0ee568e577be47941`
  và quyền `workers_scripts:write`. Cấu hình Wrangler ghi rõ account này để
  lần deploy tiếp theo không phụ thuộc account cache cục bộ.
- Mã Worker triển khai từ `d373255`; thay đổi cấu hình tiếp theo chỉ ghi rõ
  account đích, không đổi mã xử lý hoặc URL ứng dụng.
- URL giữ nguyên: `https://healway-chatbot.healway-hospital.workers.dev`.
- CLI xác nhận upload, trigger deployment và binding `CHAT_LIMITER`.
  `deployments status` xác nhận version mới nhận 100% lưu lượng.
- Version trước: `f1fedfdf-1805-426a-8944-8bfeb5a442b8`.
- Kiểm tra endpoint mới: **5/5 PASS** — thiếu token 401, token sai định dạng 401,
  origin lạ 403, preflight origin hợp lệ 204 kèm CORS đúng, tuyến không tồn tại 404.
- Chỉ xác nhận tên secret tồn tại; chưa kiểm tra tính hợp lệ/hạn mức OpenAI key
  hoặc phản hồi mô hình thật. Không dùng tài khoản bệnh nhân để chạy probe.

Evidence: [deploy log](evidence/cloudflare-deploy.txt),
[live smoke JSON](evidence/cloudflare-live-smoke.json).

## Cài và mở APK trên Android emulator

- Bản APK bổ sung dùng riêng `emulator-5582`, AVD Pixel_7 với `-read-only`, không tải/lưu snapshot.
- ADB install trả `Success`; `am start -W` trả `Status: ok`, cold start 4150 ms.
- Đã xóa dữ liệu riêng của app trong phiên tạm trước khi mở, không dùng tài khoản cũ.
- Đối chiếu APK SHA-256 với bản đã build/test; thấy màn đăng nhập HealWay,
  process còn hoạt động, không có log `FATAL EXCEPTION`/`Unhandled Exception`.
- Đây là kiểm tra cài/khởi động/màn chưa đăng nhập; không thay thế role routing
  có đăng nhập và phản hồi mô hình AI thật.

Evidence: [install](evidence/android-install.txt), [launch](evidence/android-launch.txt),
[startup JSON](evidence/android-startup.json), [ảnh Android](evidence/android-login.png).

## Điều kiện sử dụng còn thiếu

- Các thao tác admin gọi `adminCommand`, gồm tạo bác sĩ, vẫn cần backend Function.
  Việc có APK và Rules không làm các thao tác này hoạt động khi Function chưa có.
- Worker đã triển khai và giữ secret hiện có. Cần kiểm tra chatbot có đăng nhập
  bằng tài khoản thử còn hoạt động để xác nhận luồng Firestore/quota/mô hình thật.
- Cần kiểm thử có đăng nhập với tài khoản thử của Patient/Doctor/Admin, chạy AI
  thật và cài APK để kết luận nghiệm thu end-to-end. Bộ 344 Flutter/40 Firebase/
  58 Worker test vẫn là bằng chứng tự động, không thay thế các bước đó.

Không kết luận hoàn thành 100% các tiêu chí nghiệm thu môi trường thật.
