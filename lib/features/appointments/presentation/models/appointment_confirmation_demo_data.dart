abstract final class AppointmentConfirmationDemoData {
  /// Only local demo doctors have a sample price. Other doctors remain unpriced.
  static int? feeForDoctor(String id) =>
      const {'demo-morning', 'demo-afternoon'}.contains(id) ? 150000 : null;
}
