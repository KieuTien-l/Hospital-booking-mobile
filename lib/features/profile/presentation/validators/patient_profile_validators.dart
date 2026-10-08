abstract final class PatientProfileValidators {
  static final _letters = RegExp(
    r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žƠơƯưẠ-ỹ\u0300-\u036f]+(?:[ '\-][A-Za-zÀ-ÖØ-öø-ÿĀ-žƠơƯưẠ-ỹ\u0300-\u036f]+)*$",
  );
  static final _controls = RegExp(r'[\x00-\x1f\x7f]');

  static String? name(String? value, String label) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Vui lòng nhập $label.';
    if (text.length > 100) return '$label không được vượt quá 100 ký tự.';
    if (!_letters.hasMatch(text)) {
      return '$label chỉ được chứa chữ cái, khoảng trắng, dấu gạch nối hoặc dấu nháy.';
    }
    return null;
  }

  static String? selection(String? value, String label, List<String> options) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng chọn $label.';
    return options.contains(value) ? null : '$label không hợp lệ.';
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9]+(?:[ .-][0-9]+)*$').hasMatch(text)) {
      return 'Số điện thoại không hợp lệ.';
    }
    final digits = text.replaceAll(RegExp(r'[ .-]'), '');
    final valid = digits.startsWith('+')
        ? RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(digits)
        : RegExp(r'^0[0-9]{9}$').hasMatch(digits);
    return valid
        ? null
        : 'Nhập số điện thoại 10 chữ số hoặc số quốc tế có dấu +.';
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 254) return 'Email không được vượt quá 254 ký tự.';
    final parts = text.split('@');
    if (parts.length != 2) return 'Email không hợp lệ.';
    final local = parts.first;
    final domain = parts.last.split('.');
    final valid =
        local.length <= 64 &&
        RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$").hasMatch(local) &&
        !local.startsWith('.') &&
        !local.endsWith('.') &&
        !local.contains('..') &&
        domain.length >= 2 &&
        domain.every(
          (part) =>
              part.length <= 63 &&
              RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$')
                  .hasMatch(part),
        ) &&
        RegExp(r'^[A-Za-z]{2,63}$').hasMatch(domain.last);
    return valid ? null : 'Email không hợp lệ.';
  }

  static String? document(String? value, String key) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (key == 'passport') {
      return RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(text)
          ? null
          : 'Hộ chiếu phải có 6–20 chữ cái hoặc chữ số, không chứa khoảng trắng.';
    }
    return RegExp(r'^[0-9]{12}$').hasMatch(text)
        ? null
        : '${key == 'nationalId' ? 'CCCD' : 'Số định danh cá nhân'} phải gồm đúng 12 chữ số.';
  }

  static String? address(String? value, String label, {int maxLength = 100}) {
    if (value == null || value.isEmpty) return null;
    final text = value.trim();
    if (text.isEmpty) return '$label không được chỉ chứa khoảng trắng.';
    if (text.length > maxLength) {
      return '$label không được vượt quá $maxLength ký tự.';
    }
    if (_controls.hasMatch(text) || !RegExp(r'[A-Za-z0-9À-ỹ]').hasMatch(text)) {
      return '$label không hợp lệ.';
    }
    return null;
  }
}
