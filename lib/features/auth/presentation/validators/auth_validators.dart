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
}
