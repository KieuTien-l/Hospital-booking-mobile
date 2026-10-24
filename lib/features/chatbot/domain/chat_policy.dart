/// Client-side privacy gate. The Worker independently checks the entire request.
class ChatPolicy {
  static const maxMessageLength = 2000;
  static const privacyMessage =
      'Để bảo vệ quyền riêng tư, không gửi mật khẩu, mã OTP/xác thực, số thẻ hoặc bệnh án trong chat.';

  static String? validate(String value) {
    if (value.trim().isEmpty || value.length > maxMessageLength) {
      return 'Tin nhắn phải có từ 1 đến 2000 ký tự.';
    }
    if (RegExp(
          r'(mật khẩu|mat khau|password|mã otp|ma otp|\botp\b|mã xác thực|ma xac thuc|số thẻ|so the|thẻ ngân hàng|the ngan hang|cvv|bệnh án|benh an|hồ sơ bệnh án|ho so benh an)',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(value) ||
        RegExp(r'\b\d{12,19}\b')
            .hasMatch(value.replaceAll(RegExp(r'[ -]'), '')) ||
        RegExp(r'sk-(?:proj-)?[a-zA-Z0-9_-]{16,}').hasMatch(value)) {
      return privacyMessage;
    }
    return null;
  }
}
