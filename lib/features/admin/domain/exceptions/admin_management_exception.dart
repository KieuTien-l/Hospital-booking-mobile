class AdminManagementException implements Exception {
  const AdminManagementException(this.message);

  final String message;

  @override
  String toString() => message;
}
