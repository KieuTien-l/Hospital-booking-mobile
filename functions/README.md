# Vận hành Cloud Functions

## Backfill timestamp ca khám

Sau khi deploy `adminCommand`, chạy thao tác `backfillSlotTimes` bằng một tài khoản admin đang hoạt động. Mỗi request phải có `requestId` mới và `reason`; truyền lại `nextCursor` của phản hồi cho đợt kế tiếp cho đến khi nhận `nextCursor: null`.

```json
{
  "requestId": "slot-time-migration-001",
  "operation": "backfillSlotTimes",
  "reason": "Bổ sung startsAt/endsAt cho ca cũ",
  "values": { "limit": 100, "cursor": null }
}
```

Lệnh chỉ ghi `startsAt`, `endsAt`, `updatedAt` cho ca chưa có đủ hai timestamp. Nếu gặp ca thiếu lịch hoặc giờ sai, toàn bộ đợt bị từ chối để dữ liệu lỗi được sửa thủ công trước, không tạo timestamp đoán sai.
