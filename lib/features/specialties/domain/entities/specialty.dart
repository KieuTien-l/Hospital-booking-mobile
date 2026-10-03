class Specialty {
  const Specialty({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.status = 'ACTIVE',
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String status;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get tenChuyenKhoa => name;
  String get moTa => description;
  String? get hinhAnh => imageUrl;
  String get trangThai => status;
}
