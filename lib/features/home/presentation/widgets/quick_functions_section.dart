import 'dart:ui';

import 'package:flutter/material.dart';

const _blue = Color(0xFF0065B8);
const _ink = Color(0xFF163958);

const _features = <(String, IconData, Color)>[
  ('Đặt khám', Icons.calendar_month_outlined, _blue),
  ('Lịch đặt khám', Icons.event_available_outlined, Color(0xFF009AAB)),
  (
    'Thanh toán viện phí',
    Icons.account_balance_wallet_outlined,
    Color(0xFFDB8C35),
  ),
  ('Hồ sơ sức khỏe', Icons.folder_shared_outlined, Color(0xFF6086D5)),
  ('Kết quả cận lâm sàng', Icons.biotech_outlined, Color(0xFF12A091)),
  ('Lắng nghe khách hàng', Icons.support_agent_outlined, Color(0xFFDA7B89)),
  ('Hướng dẫn sử dụng', Icons.menu_book_outlined, Color(0xFF7C75C9)),
  ('Hỏi - đáp (Chatbot)', Icons.smart_toy_outlined, Color(0xFF218CC3)),
];

class QuickFunctionsSection extends StatelessWidget {
  const QuickFunctionsSection({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onOpen,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final matches = _features
        .where((f) => f.$1.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn cần hỗ trợ gì?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm chức năng',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: IconButton(
                    tooltip: 'Tìm kiếm',
                    onPressed: () => FocusScope.of(context).unfocus(),
                    icon: const Icon(Icons.search, color: _blue),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Không tìm thấy chức năng phù hợp.'),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 310 ? 3 : 4;
                  return Wrap(
                    runSpacing: 18,
                    children: matches
                        .map(
                          (f) => SizedBox(
                            width: constraints.maxWidth / columns,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => onOpen(f.$1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: f.$3.withValues(alpha: .10),
                                          borderRadius: BorderRadius.circular(
                                            17,
                                          ),
                                        ),
                                        child: Icon(
                                          f.$2,
                                          color: f.$3,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      Text(
                                        f.$1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          fontWeight: FontWeight.w600,
                                          color: _ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
