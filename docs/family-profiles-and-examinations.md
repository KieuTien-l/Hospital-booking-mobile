# Hồ sơ gia đình và phiếu khám

Mỗi document `BENH_NHAN` là một người bệnh độc lập. `ownerUserId` là tài
khoản quản lý hồ sơ; vì vậy một tài khoản có thể có hồ sơ của bản thân, cha
mẹ hoặc người thân. `patientId` (document ID) là khóa liên kết kỹ thuật;
`patientCode` (`HS-XXXX-XXXX`) là mã cố định để hiển thị trên chứng từ.

```text
BENH_NHAN/{patientId}
  ownerUserId, authUserId, patientCode

LICH_HEN/{appointmentId}
  patientId, patientCode

PHIEU_KHAM/{appointmentId}
  patientId, patientCode, appointmentId, visitCode, doctorId, status

HO_SO_SUC_KHOE/{recordId}
  patientId, patientCode, appointmentId, examinationId

KET_QUA_CLS/{resultId}
  patientId, patientCode, appointmentId, examinationId
```

`PHIEU_KHAM` có ID đúng bằng `appointmentId`, vì một lịch hẹn có một phiếu
khám. Bác sĩ tạo phiếu qua Worker bằng thao tác **Bắt đầu khám**; admin chỉ
được đọc/tra cứu. Khi phiếu hoàn tất, Worker cập nhật trạng thái lịch hẹn và
phiếu khám cùng lúc.

Trước khi deploy Rules mới cho dữ liệu đang có, chạy dry-run rồi apply script
`migrate-patient-codes.mjs` trong thư mục `scripts/`. Script bổ sung
`ownerUserId`, `patientCode` và registry `MA_HO_SO`, không đổi document ID cũ.
