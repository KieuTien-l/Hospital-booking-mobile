import 'package:flutter/material.dart';

import 'usage_guide_ui_model.dart';

/// Local editorial samples, independent of account and backend state.
abstract final class UsageGuideDemoData {
  static const guides = [
    UsageGuideUiModel(
      id: 'account',
      title: 'Hướng dẫn đăng ký và đăng nhập',
      description: 'Bắt đầu sử dụng HealWay bằng tài khoản của bạn.',
      icon: Icons.login_rounded,
      steps: [
        'Mở ứng dụng HealWay.',
        'Chọn “Đăng ký” nếu chưa có tài khoản.',
        'Nhập họ tên, email, số điện thoại và mật khẩu.',
        'Hoàn tất đăng ký theo hướng dẫn trên màn hình.',
        'Đăng nhập bằng email và mật khẩu.',
      ],
    ),
    UsageGuideUiModel(
      id: 'profile',
      title: 'Hướng dẫn tạo hồ sơ người bệnh',
      description: 'Chuẩn bị thông tin hồ sơ để chọn khi đặt khám.',
      icon: Icons.folder_shared_outlined,
      steps: [
        'Đăng nhập vào HealWay.',
        'Vào chức năng “Đặt khám”.',
        'Tại màn hình Chọn hồ sơ, chọn “Thêm mới hồ sơ”.',
        'Nhập thông tin cá nhân theo biểu mẫu.',
        'Kiểm tra thông tin và chọn “Tạo hồ sơ khám bệnh”.',
        'Quay về danh sách và chọn hồ sơ cần đặt khám.',
      ],
    ),
    UsageGuideUiModel(
      id: 'booking',
      title: 'Hướng dẫn đặt lịch khám',
      description:
          'Chọn hồ sơ, lịch khám và kiểm tra thông tin trước khi tiếp tục.',
      icon: Icons.calendar_month_outlined,
      steps: [
        'Tại trang chủ, chọn “Đặt khám”.',
        'Chọn hồ sơ người bệnh.',
        'Chọn chuyên khoa.',
        'Chọn ngày khám.',
        'Chọn bác sĩ và khung giờ còn khả dụng.',
        'Xác nhận thông tin khám và lựa chọn bảo hiểm.',
        'Kiểm tra thông tin đặt khám và thông tin thanh toán.',
        'Chọn phương thức thanh toán.',
        'Trong bản hiện tại, thanh toán và hoàn tất đặt khám chỉ là demo. Khi thanh toán thực tế được tích hợp, cần chờ hệ thống xác nhận cả thanh toán và lịch hẹn.',
      ],
    ),
    UsageGuideUiModel(
      id: 'history',
      title: 'Hướng dẫn xem lịch sử đặt khám',
      description: 'Tra cứu các lịch hẹn theo trạng thái và bộ lọc.',
      icon: Icons.history_rounded,
      steps: [
        'Mở ứng dụng HealWay.',
        'Chọn “Lịch đặt khám” trên trang chủ để mở Lịch sử đặt khám.',
        'Chọn tab trạng thái phù hợp.',
        'Sử dụng bộ lọc nếu cần.',
        'Chọn lịch hẹn để xem thông tin chi tiết khi chức năng đã hỗ trợ. Dữ liệu minh họa được đánh dấu riêng.',
      ],
    ),
  ];
  static const faqs = [
    FaqUiModel(
      id: 'password',
      category: FaqCategory.account,
      question: 'Tôi quên mật khẩu đăng nhập thì phải làm sao?',
      answer: 'Tại màn hình Đăng nhập, chọn “Quên mật khẩu”, nhập email đã đăng ký và làm theo hướng dẫn trong email khôi phục mật khẩu.',
    ),
    FaqUiModel(
      id: 'relative',
      category: FaqCategory.booking,
      question: 'Tôi có thể đặt lịch khám cho người thân không?',
      answer: 'Bạn có thể tạo hoặc chọn hồ sơ người bệnh phù hợp trong chức năng Đặt khám, sau đó tiếp tục lựa chọn chuyên khoa, ngày khám và khung giờ.',
    ),
    FaqUiModel(
      id: 'appointments',
      category: FaqCategory.booking,
      question: 'Làm thế nào để xem lại lịch khám đã đặt?',
      answer: 'Chọn “Lịch đặt khám” trên trang chủ để mở Lịch sử đặt khám. Bạn có thể xem lịch hẹn theo trạng thái khi dữ liệu đã được hệ thống cập nhật. Dữ liệu demo có nhãn minh họa.',
    ),
    FaqUiModel(
      id: 'methods',
      category: FaqCategory.payment,
      question: 'HealWay hỗ trợ những phương thức thanh toán nào?',
      answer: 'Theo phạm vi thiết kế hiện tại, HealWay dự kiến hỗ trợ ví MoMo, chuyển khoản ngân hàng và mã QR ngân hàng.\n\nCác phương thức hiện chỉ có giao diện demo và chỉ sử dụng được để thanh toán thực tế khi hệ thống đã tích hợp và kích hoạt.',
    ),
  ];
}
