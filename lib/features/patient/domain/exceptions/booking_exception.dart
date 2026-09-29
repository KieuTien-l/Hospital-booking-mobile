/// A predictable, user-facing failure raised when a booking cannot be made.
class BookingException implements Exception {
  const BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}
