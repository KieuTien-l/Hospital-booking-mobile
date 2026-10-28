/// Shared input checks for the authentication forms.
class AuthValidators {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$').hasMatch(email)) {
      return 'Vui lòng nhập email đúng định dạng';
    }
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.runes.length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
    return null;
  }

  /// The Firestore patient profile requires a Vietnamese phone number.
  /// Validate it before creating Firebase Auth so an account is never left
  /// without its corresponding patient profile.
  static String? vietnamesePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (!RegExp(r'^0[0-9]{9,10}$').hasMatch(phone)) {
      return 'Số điện thoại phải có 10–11 số và bắt đầu bằng 0';
    }
    return null;
  }
}
