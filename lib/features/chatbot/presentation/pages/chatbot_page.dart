import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chatbot_controller.dart';

const _blue = Color(0xFF0065B8);
const _ink = Color(0xFF163958);
const _muted = Color(0xFF5685A6);

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  static const _suggestions = [
    (
      icon: Icons.calendar_month_outlined,
      title: 'Đặt lịch khám',
      detail: 'Hướng dẫn từng bước',
      color: Color(0xFF0878CF),
      question: 'Tôi muốn được hướng dẫn đặt khám.',
    ),
    (
      icon: Icons.local_hospital_outlined,
      title: 'Chuyên khoa',
      detail: 'Tìm hiểu trước khi khám',
      color: Color(0xFF0C938B),
      question: 'Tôi muốn tìm hiểu về các chuyên khoa.',
    ),
    (
      icon: Icons.assignment_outlined,
      title: 'Trước khi khám',
      detail: 'Giấy tờ và điều cần biết',
      color: Color(0xFF7562BD),
      question: 'Tôi cần chuẩn bị những gì trước khi đi khám?',
    ),
    (
      icon: Icons.help_outline_rounded,
      title: 'Dùng HealWay',
      detail: 'Khám phá các tiện ích',
      color: Color(0xFFCA8740),
      question: 'Hướng dẫn tôi sử dụng ứng dụng HealWay.',
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send(ChatbotController controller) async {
    final message = _input.text.trim();
    if (message.isEmpty || controller.isSending) return;
    _input.clear();
    await controller.send(message);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _reset(ChatbotController controller) {
    controller.reset();
    _input.clear();
    _focus.unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatbotController>();
    final messages = controller.messages;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'BeVietnamPro',
          bodyColor: _ink,
          displayColor: _ink,
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF5FF), Color(0xFFF7FAFD), Color(0xFFF7FAFD)],
            stops: [0, .45, 1],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: _ink,
            toolbarHeight: 68,
            titleSpacing: 0,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFAEBCC8)),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý HealWay',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Đồng hành cùng sức khỏe của bạn',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
            actions: [
              IconButton.outlined(
                onPressed:
                    controller.isSending ||
                        (messages.isEmpty && _input.text.isEmpty)
                    ? null
                    : () => _reset(controller),
                tooltip: 'Cuộc trò chuyện mới',
                style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD5E6F3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: .7),
                ),
                icon: const Icon(Icons.edit_square, size: 21),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        children: [
                          if (messages.isEmpty) ...[
                            _welcome(),
                            const SizedBox(height: 26),
                            const Text(
                              'Gợi ý dành cho bạn',
                              style: TextStyle(
                                fontSize: 17,
                                color: _ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Chọn một chủ đề để bắt đầu trò chuyện',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                            const SizedBox(height: 16),
                            _suggestionCards(),
                            const SizedBox(height: 20),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 14,
                                  color: _muted,
                                ),
                                SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'Hoặc nhập câu hỏi của riêng bạn bên dưới',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          for (final message in messages) ...[
                            const SizedBox(height: 16),
                            _MessageBubble(
                              text: message.text,
                              isUser: message.isUser,
                            ),
                          ],
                          if (controller.isSending) ...[
                            const SizedBox(height: 16),
                            const _TypingBubble(),
                          ],
                          if (controller.errorMessage != null) ...[
                            const SizedBox(height: 18),
                            _ErrorNotice(
                              message: controller.errorMessage!,
                              onRetry: controller.retry,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _composer(controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
    child: Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFBDD6EA)),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: .08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.smart_toy_outlined, color: _blue, size: 33),
        ),
        const SizedBox(height: 18),
        const Text(
          'Xin chào bạn!',
          style: TextStyle(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mình có thể giúp gì cho bạn?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 23,
            height: 1.4,
            letterSpacing: -.5,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Hỗ trợ sử dụng HealWay, đặt lịch khám\nvà thông tin sức khỏe phổ thông.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.7, color: _muted),
        ),
        const SizedBox(height: 12),
        const _SafetyNotice(),
      ],
    ),
  );
  Widget _suggestionCards() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 300 ? 1 : 2;
      return Column(
        children: [
          for (var row = 0; row < _suggestions.length; row += columns) ...[
            if (row > 0) const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < columns; col++) ...[
                    if (col > 0) const SizedBox(width: 12),
                    Expanded(child: _suggestionCard(row + col)),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _suggestionCard(int index) {
    final suggestion = _suggestions[index];
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: .035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFB7C9D8), width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            setState(() {
              _input.text = suggestion.question;
              _input.selection = TextSelection.collapsed(
                offset: _input.text.length,
              );
            });
            _focus.requestFocus();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: suggestion.color.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        suggestion.icon,
                        color: suggestion.color,
                        size: 23,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.north_east_rounded,
                      color: Color(0xFF9BB1C2),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  suggestion.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _composer(ChatbotController controller) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    decoration: BoxDecoration(color: const Color(0xFFF7FAFD)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFAFC4D5), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(controller),
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 14, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Nhập câu hỏi của bạn…',
                    hintStyle: const TextStyle(color: _muted, fontSize: 13),
                    counterText: '',
                    filled: false,
                    contentPadding: const EdgeInsets.all(15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: _input.text.trim().isEmpty || controller.isSending
                    ? null
                    : () => _send(controller),
                tooltip: 'Gửi tin nhắn',
                style: IconButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE3EEF7),
                  disabledForegroundColor: _muted,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Chỉ hỗ trợ HealWay và sức khỏe phổ thông. Không chẩn đoán, kê đơn hoặc xử lý cấp cứu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.5, color: _muted),
        ),
      ],
    ),
  );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F8FD),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFC8DDEC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.health_and_safety_outlined, color: _blue, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Nếu đau ngực dữ dội, khó thở, ngất hoặc chảy máu nhiều, hãy gọi cấp cứu hoặc đến cơ sở y tế gần nhất ngay.',
            style: TextStyle(fontSize: 11, height: 1.45, color: _ink),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, this.isUser = false});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!isUser) ...[
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(Icons.smart_toy_outlined, color: _blue, size: 19),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * .80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: isUser ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(18).copyWith(
              topLeft: Radius.circular(isUser ? 18 : 4),
              topRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isUser ? Colors.white : _ink,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        child: Icon(Icons.smart_toy_outlined, color: _blue, size: 19),
      ),
      SizedBox(width: 8),
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            'Trợ lý đang soạn câu trả lời…',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ),
      ),
    ],
  );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4F1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF2B8AC)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFC83E2A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: _ink, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
