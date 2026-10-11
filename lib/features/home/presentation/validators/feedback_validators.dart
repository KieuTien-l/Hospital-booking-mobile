abstract final class FeedbackValidators {
  static String? title(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Vui lòng nhập tiêu đề phản hồi.';
    if ((value ?? '').length > 100) return 'Tiêu đề tối đa 100 ký tự.';
    return null;
  }

  static String? content(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Vui lòng nhập nội dung phản hồi.';
    if (text.length < 10) {
      return 'Nội dung cần ít nhất 10 ký tự sau khi bỏ khoảng trắng đầu/cuối.';
    }
    if ((value ?? '').length > 1000) return 'Nội dung tối đa 1000 ký tự.';
    return null;
  }
}
