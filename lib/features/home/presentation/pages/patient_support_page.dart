import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../widgets/patient_home_background.dart';

/// Small self-service pages for the Home and Functions entries that do not
/// require a patient Firestore record. They replace dead-end "coming soon"
/// sheets while keeping hospital-owned information out of hard-coded records.
enum PatientSupportKind { chatbot, servicePrices, contact, policy, settings }

class PatientSupportPage extends StatefulWidget {
  const PatientSupportPage({super.key, required this.kind});

  final PatientSupportKind kind;

  @override
  State<PatientSupportPage> createState() => _PatientSupportPageState();
}

class _PatientSupportPageState extends State<PatientSupportPage> {
  final _questionController = TextEditingController();
  final _messages = <_SupportMessage>[
    const _SupportMessage(
      fromPatient: false,
      text: 'Chào bạn. Hãy chọn một câu hỏi bên dưới hoặc nhập câu hỏi để nhận hướng dẫn sử dụng HealWay.',
    ),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    PatientSupportKind.chatbot => 'Hỏi đáp HealWay',
    PatientSupportKind.servicePrices => 'Bảng giá dịch vụ',
    PatientSupportKind.contact => 'Liên hệ / Hỗ trợ',
    PatientSupportKind.policy => 'Chính sách & điều khoản',
    PatientSupportKind.settings => 'Cài đặt',
  };

  void _ask(String question) {
    final value = question.trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(_SupportMessage(fromPatient: true, text: value));
      _messages.add(
        _SupportMessage(fromPatient: false, text: _answerFor(value)),
      );
      _questionController.clear();
    });
  }

  String _answerFor(String question) {
    final normalized = question.toLowerCase();
    if (normalized.contains('đặt') || normalized.contains('lịch')) {
      return 'Vào Đặt khám, chọn hồ sơ, chuyên khoa, ngày và khung giờ trống. Sau khi xác nhận, bạn sẽ nhận được thông báo trong ứng dụng.';
    }
    if (normalized.contains('hủy') || normalized.contains('đổi')) {
      return 'Vào Lịch đặt khám, chọn lịch ở trạng thái Đã xác nhận, rồi chọn Thay đổi lịch hoặc Hủy lịch.';
    }
    if (normalized.contains('kết quả') || normalized.contains('xét nghiệm')) {
      return 'Vào Kết quả cận lâm sàng để xem dữ liệu bệnh viện đã trả. Bạn có thể lọc theo loại và năm.';
    }
    if (normalized.contains('thanh toán') || normalized.contains('phí')) {
      return 'Vào Thanh toán viện phí để xem các giao dịch gắn với hồ sơ. Màn thanh toán online hiện chưa chuyển tiền trực tiếp.';
    }
    return 'Bạn có thể xem Hướng dẫn sử dụng hoặc gửi phản hồi trong mục Lắng nghe khách hàng để được hỗ trợ thêm.';
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: PatientHomeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textOnPrimary,
          title: Text(
            _title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: switch (widget.kind) {
                PatientSupportKind.chatbot => _chatbot(),
                PatientSupportKind.servicePrices => _servicePrices(),
                PatientSupportKind.contact => _contact(),
                PatientSupportKind.policy => _policy(),
                PatientSupportKind.settings => _settings(),
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _chatbot() => Column(
    children: [
      Expanded(
        child: ListView(
          key: const PageStorageKey('support-chat'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            for (final message in _messages) _messageBubble(message),
            const SizedBox(height: 8),
            const Text(
              'Câu hỏi thường gặp',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        'Cách đặt lịch khám?',
                        'Cách thay đổi hoặc hủy lịch?',
                        'Xem kết quả xét nghiệm ở đâu?',
                        'Thanh toán viện phí như thế nào?',
                      ]
                      .map(
                        (question) => ActionChip(
                          label: Text(question),
                          onPressed: () => _ask(question),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _ask,
                  decoration: const InputDecoration(
                    hintText: 'Nhập câu hỏi của bạn',
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Gửi câu hỏi',
                onPressed: () => _ask(_questionController.text),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _messageBubble(_SupportMessage message) => Align(
    alignment: message.fromPatient
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: message.fromPatient
            ? AppColors.textOnPrimary
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: message.fromPatient ? Colors.white : AppColors.textPrimary,
          height: 1.45,
        ),
      ),
    ),
  );

  Widget _servicePrices() => _scrollCard(
    title: 'Tra cứu chi phí khám',
    icon: Icons.payments_outlined,
    sections: const [
      _SupportSection(
        'Phí khám theo bác sĩ',
        'Phí khám được hiển thị trước khi bạn xác nhận đặt lịch, dựa trên bác sĩ và chuyên khoa đã chọn.',
      ),
      _SupportSection(
        'Dịch vụ kỹ thuật',
        'Kết quả, chỉ định và khoản viện phí chỉ xuất hiện sau khi bệnh viện cập nhật dữ liệu cho hồ sơ của bạn.',
      ),
      _SupportSection(
        'Lưu ý',
        'Thông tin trên ứng dụng dùng để tham khảo. Chi phí chính thức được bệnh viện xác nhận tại thời điểm khám hoặc thanh toán.',
      ),
    ],
  );

  Widget _contact() => _scrollCard(
    title: 'Kênh hỗ trợ trong HealWay',
    icon: Icons.support_agent_outlined,
    sections: const [
      _SupportSection(
        'Đặt lịch và lịch hẹn',
        'Dùng mục Đặt khám hoặc Lịch đặt khám để tạo, xem, thay đổi hay hủy lịch.',
      ),
      _SupportSection(
        'Gửi phản hồi',
        'Dùng mục Lắng nghe khách hàng để gửi góp ý trực tiếp kèm mức đánh giá.',
      ),
      _SupportSection(
        'Thông tin liên hệ chính thức',
        'Số điện thoại và email hỗ trợ sẽ được hiển thị tại đây khi bệnh viện cấu hình dữ liệu liên hệ.',
      ),
    ],
  );

  Widget _policy() => _scrollCard(
    title: 'Quyền riêng tư và điều khoản',
    icon: Icons.privacy_tip_outlined,
    sections: const [
      _SupportSection(
        'Dữ liệu hồ sơ',
        'Ứng dụng chỉ hiển thị hồ sơ, lịch hẹn, kết quả và thanh toán thuộc bệnh nhân đang đăng nhập.',
      ),
      _SupportSection(
        'Chia sẻ thông tin',
        'Không chia sẻ mật khẩu, mã xác nhận hoặc ảnh giấy tờ tùy thân với người khác.',
      ),
      _SupportSection(
        'Điều khoản chính thức',
        'Văn bản điều khoản do bệnh viện ban hành sẽ được cập nhật tại đây khi có phiên bản được phê duyệt.',
      ),
    ],
  );

  Widget _settings() => _scrollCard(
    title: 'Thiết lập ứng dụng',
    icon: Icons.settings_outlined,
    sections: const [
      _SupportSection(
        'Thông báo lịch hẹn',
        'Thông báo đặt lịch và thay đổi trạng thái được xem trong tab Thông báo.',
      ),
      _SupportSection(
        'Bảo mật tài khoản',
        'Dùng mục Đổi mật khẩu để nhận liên kết đặt lại mật khẩu qua email đã đăng ký.',
      ),
      _SupportSection(
        'Cài đặt nâng cao',
        'Các tùy chọn cá nhân hóa sẽ được đồng bộ khi bệnh viện công bố chính sách cấu hình tài khoản.',
      ),
    ],
  );

  Widget _scrollCard({
    required String title,
    required IconData icon,
    required List<_SupportSection> sections,
  }) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.textOnPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thông tin được trình bày để bạn sử dụng các chức năng hiện có trong ứng dụng.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              const Divider(height: 28),
              Text(
                section.title,
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                section.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SupportMessage {
  const _SupportMessage({required this.fromPatient, required this.text});

  final bool fromPatient;
  final String text;
}

class _SupportSection {
  const _SupportSection(this.title, this.content);

  final String title;
  final String content;
}
