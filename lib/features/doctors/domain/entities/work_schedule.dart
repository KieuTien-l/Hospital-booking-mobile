class WorkSchedule {
  const WorkSchedule({
    required this.id,
    required this.doctorId,
    this.workDate,
    this.startTime,
    this.endTime,
    this.status = 'ACTIVE',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String doctorId;
  final DateTime? workDate;
  final String? startTime;
  final String? endTime;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get maBacSi => doctorId;
  String get trangThai => status;
}
