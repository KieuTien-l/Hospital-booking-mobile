# Báo cáo refactor HealWay

## A. Vấn đề phát hiện

- `core/models` chứa business models và domain phụ thuộc model Firebase.
- `features/patient` gom nhiều nghiệp vụ; sáu repository gọi Firestore trực tiếp.
- State nằm trong `presentation/providers`, chưa theo cấu trúc controllers.
- `AuthGate` trong app tạo vòng import với onboarding.
- Wrapper `PatientHomeScreen` không có caller trong source/test; Auth screens cũ đã bị xóa tại merge.
- Build report Android được Git theo dõi.

Phân tích lịch sử chỉ đọc: merge `70c6da5`, parent KieuTien `fb6af96`, parent QuocViet `69d31b3`. So với parent KieuTien, merge bổ sung patient/models/REST Auth; so với parent QuocViet, merge bổ sung patient Home view, wrapper, onboarding/preferences và tests. Auth pages và các Home pages hiện tại là implementation đang được sử dụng. Chỉ so sánh lịch sử để xác định nguồn code, không chuyển branch.

## B. Mapping

| File hiện tại | Vị trí mới | Hành động | Lý do |
|---|---|---|---|
| `lib/core/models/specialty_model.dart` | `lib/features/specialties/data/models/specialty_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/specialty_repository.dart` | `lib/features/specialties/domain/repositories/specialty_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_specialty_repository.dart` | `lib/features/specialties/data/datasources/specialty_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/doctor_model.dart` | `lib/features/doctors/data/models/doctor_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/doctor_repository.dart` | `lib/features/doctors/domain/repositories/doctor_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_doctor_repository.dart` | `lib/features/doctors/data/datasources/doctor_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/work_schedule_model.dart` | `lib/features/doctors/data/models/work_schedule_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/work_schedule_repository.dart` | `lib/features/doctors/domain/repositories/work_schedule_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_work_schedule_repository.dart` | `lib/features/doctors/data/datasources/work_schedule_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/time_slot_model.dart` | `lib/features/doctors/data/models/time_slot_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/time_slot_repository.dart` | `lib/features/doctors/domain/repositories/time_slot_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_time_slot_repository.dart` | `lib/features/doctors/data/datasources/time_slot_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/appointment_model.dart` | `lib/features/appointments/data/models/appointment_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/appointment_repository.dart` | `lib/features/appointments/domain/repositories/appointment_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_appointment_repository.dart` | `lib/features/appointments/data/datasources/appointment_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/patient_model.dart` | `lib/features/profile/data/models/patient_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/patient_repository.dart` | `lib/features/profile/domain/repositories/patient_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_patient_repository.dart` | `lib/features/profile/data/datasources/patient_firebase_datasource.dart` | Di chuyển phần Firebase; tạo repository delegate | Đúng feature và layer sở hữu |
| `lib/core/models/user_model.dart` | `lib/features/auth/data/models/user_model.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/core/models/model_value_parser.dart` | `lib/core/utils/model_value_parser.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/core/entities/user_entity.dart` | `lib/features/auth/domain/entities/user_entity.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/core/network/api_exception.dart` | `lib/features/auth/data/exceptions/api_exception.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/core/storage/app_preferences.dart` | `lib/features/onboarding/data/datasources/app_preferences.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/auth/presentation/providers/auth_provider.dart` | `lib/features/auth/presentation/controllers/auth_controller.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/presentation/providers/patient_booking_provider.dart` | `lib/features/appointments/presentation/controllers/appointment_controller.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/repositories/patient_booking_repository.dart` | `lib/features/appointments/domain/repositories/booking_repository.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/data/repositories/firebase_patient_booking_repository.dart` | `lib/features/appointments/data/repositories/booking_repository_impl.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/exceptions/booking_exception.dart` | `lib/features/appointments/domain/exceptions/booking_exception.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `lib/features/patient/domain/usecases/book_appointment.dart` | `lib/features/appointments/domain/usecases/book_appointment.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `test/features/patient/domain/usecases/book_appointment_test.dart` | `test/features/appointments/domain/usecases/book_appointment_test.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `test/core/models/models_test.dart` | `test/features/data/models_test.dart` | Di chuyển/đổi tên; sửa import | Đúng feature và layer sở hữu |
| `AuthGate` trong `lib/app.dart` | `lib/core/routes/auth_gate.dart` | Tách | Routing dùng chung; loại bỏ vòng import |
| `lib/features/home/screens/patient_home_screen.dart` | — | Xóa sau kiểm tra references | Wrapper không có caller; giữ PatientHomePage và PatientHomeView |
| `android/build/reports/problems/problems-report.html` | — | Xóa | Build output; thêm `**/build/` vào ignore |

## C. Đã thay đổi

- Di chuyển 31 file theo mapping; sửa tất cả import trong lib và test.
- Tách sáu entity thuần Dart: Specialty, Doctor, WorkSchedule, TimeSlot, Appointment, Patient. Giữ nguyên tên entity, constructor, trường và getter. Các lớp `*Model` kế thừa entity, giữ serialization và collection constants.
- Tạo sáu repository implementation gọi các datasource đã tách; repository và domain không import Firebase.
- BookingRepositoryImpl giữ facade của luồng booking/profile và nhận sáu repository interface. Không bỏ phương thức hiện có.
- AuthController và AppointmentController vẫn dùng Provider/ChangeNotifier; giữ các phương thức và trạng thái.
- UserModel chỉ được Auth dùng nên chuyển vào Auth; UserEntity do Auth sở hữu nhưng Home/router có thể dùng domain entity này. Parser được nhiều feature sử dụng nên giữ tại core/utils. ApiException chỉ phục vụ Auth REST; preferences chỉ phục vụ onboarding.
- Giữ nguyên UI, Firebase options, collection/field schema, transaction và scripts seed/migration. Home view không tách thêm trong đợt này để hạn chế phạm vi.
- Không tạo feature/thư mục rỗng cho notifications, ai_assistant hoặc chức năng chưa có implementation.
- Test models cũ giữ tất cả assertions; test serialization từ entity chuyển qua `AppointmentModel.fromEntity`. Thêm kiểm tra role routing, restore/register/logout, booking transaction và profile update.
- Khai báo `cloud_firestore_platform_interface` đã có trong lockfile thành dev dependency trực tiếp để test qua platform interface hợp lệ; không đổi phiên bản package hoặc dependency runtime/state management.

Onboarding cũng được tách qua OnboardingController → OnboardingRepository → OnboardingRepositoryImpl → AppPreferences; giữ fallback khi đọc storage lỗi và cơ chế retry khi ghi lỗi, tránh page import datasource trực tiếp.

Các file mới được tách/tạo:

- `lib/features/specialties/domain/entities/specialty.dart`
- `lib/features/specialties/data/repositories/specialty_repository_impl.dart`
- `lib/features/doctors/domain/entities/doctor.dart`
- `lib/features/doctors/data/repositories/doctor_repository_impl.dart`
- `lib/features/doctors/domain/entities/work_schedule.dart`
- `lib/features/doctors/data/repositories/work_schedule_repository_impl.dart`
- `lib/features/doctors/domain/entities/time_slot.dart`
- `lib/features/doctors/data/repositories/time_slot_repository_impl.dart`
- `lib/features/appointments/domain/entities/appointment.dart`
- `lib/features/appointments/data/repositories/appointment_repository_impl.dart`
- `lib/features/profile/domain/entities/patient.dart`
- `lib/features/profile/data/repositories/patient_repository_impl.dart`
- `lib/core/routes/auth_gate.dart`
- `lib/features/onboarding/domain/repositories/onboarding_repository.dart`
- `lib/features/onboarding/data/repositories/onboarding_repository_impl.dart`
- `lib/features/onboarding/presentation/controllers/onboarding_controller.dart`
- `test/features/auth/presentation/auth_flow_test.dart`
- `test/features/appointments/data/appointment_booking_test.dart`

## D. Kiểm tra

```text
flutter pub get: PASS; không đổi phiên bản dependency.
dart format .: PASS; 72 file, lần cuối 0 file cần thay đổi.
flutter analyze: PASS; No issues found.
flutter test: PASS; 38/38 test (25 test hiện có + 13 test hồi quy mới).
git diff --check: PASS.
```

Đối chiếu source: 11 file UI/bootstrap giữ token (bỏ khác biệt import, đổi tên AuthController và format); sáu implementation serialization và sáu implementation Firestore giữ nguyên logic sau khi đổi type/data boundary. Domain/presentation không import data model hoặc Firebase; repository implementation không import Firebase.

## E. Còn tồn tại và giới hạn

- Quên mật khẩu đang là UI placeholder chưa gọi Firebase, đã tồn tại trước refactor; giữ nguyên.
- Patient Home còn hiển thị placeholder cho đặt khám; chưa có booking page nối AppointmentController. Tầng booking hiện có được giữ và kiểm thử độc lập.
- Test Auth dùng repository giả lập; test booking/profile dùng platform Firestore giả lập trong bộ nhớ. Chưa xác minh đăng nhập hoặc ghi dữ liệu trên Firebase thật, server concurrency/security rules.
- Datasource appointment giữ validation trong transaction để bảo toàn atomic behavior; không tách nghiệp vụ transaction ra ngoài trong đợt refactor này.
- Profile giữ loại BookingException cũ qua import domain appointments để bảo toàn loại exception cho callers; chưa đổi error contract.
- Core/routes dùng domain/controller/page của Auth và Home vì đây là điểm tích hợp routing của ứng dụng.
- Không merge, pull, reset, checkout, commit hoặc push.
