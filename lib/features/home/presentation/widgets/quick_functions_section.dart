import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const _blue = Color(0xFF0753AB);
const _features = <(String, String, FaIconData, Color)>[
  ('Đặt khám', 'Đặt khám', FontAwesomeIcons.calendarPlus, Color(0xFF1685FF)),
  (
    'Lịch đặt khám',
    'Lịch đặt\nkhám',
    FontAwesomeIcons.calendarCheck,
    Color(0xFF05BF96),
  ),
  (
    'Thanh toán viện phí',
    'Thanh toán\nviện phí',
    FontAwesomeIcons.creditCard,
    Color(0xFFFF822D),
  ),
  (
    'Hồ sơ sức khỏe',
    'Hồ sơ\nsức khỏe',
    FontAwesomeIcons.fileLines,
    Color(0xFF8245FF),
  ),
  (
    'Kết quả cận lâm sàng',
    'Kết quả\ncận lâm sàng',
    FontAwesomeIcons.clipboard,
    Color(0xFFFF4D8A),
  ),
  (
    'Lắng nghe khách hàng',
    'Lắng nghe\nkhách hàng',
    FontAwesomeIcons.comments,
    Color(0xFF1685FF),
  ),
  (
    'Hướng dẫn sử dụng',
    'Hướng dẫn\nsử dụng',
    FontAwesomeIcons.rectangleList,
    Color(0xFF05BF96),
  ),
  (
    'Hỏi - đáp (Chatbot)',
    'Hỏi - đáp\n(Chatbot)',
    FontAwesomeIcons.circleQuestion,
    Color(0xFF8245FF),
  ),
];

class QuickFunctionsSection extends StatefulWidget {
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
  State<QuickFunctionsSection> createState() => _QuickFunctionsSectionState();
}

class _QuickFunctionsSectionState extends State<QuickFunctionsSection> {
  bool _searchVisible = false;

  @override
  Widget build(BuildContext context) {
    final matches = _features
        .where(
          (feature) => feature.$1.toLowerCase().contains(
            widget.query.trim().toLowerCase(),
          ),
        )
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: .52),
                const Color(0xFFD9EEFF).withValues(alpha: .42),
                Colors.white.withValues(alpha: .64),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: .9),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chức năng',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: .6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: _searchVisible ? 'Đóng tìm kiếm' : 'Tìm kiếm',
                      icon: FaIcon(
                        _searchVisible
                            ? FontAwesomeIcons.xmark
                            : FontAwesomeIcons.magnifyingGlass,
                        size: 22,
                        color: const Color(0xFF1685FF),
                      ),
                      onPressed: () {
                        setState(() => _searchVisible = !_searchVisible);
                        if (!_searchVisible) {
                          widget.onQueryChanged('');
                          FocusScope.of(context).unfocus();
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_searchVisible) ...[
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: widget.query,
                  autofocus: true,
                  onChanged: widget.onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm chức năng',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (matches.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Không tìm thấy chức năng phù hợp.'),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 4;
                  final cellWidth = constraints.maxWidth / columns;
                  final iconSize = (cellWidth * .38).clamp(22.0, 44.0);
                  final labelSize = (cellWidth * .145).clamp(10.0, 17.0);
                  return Wrap(
                    runSpacing: 16,
                    children: matches
                        .map(
                          (feature) => SizedBox(
                            width: cellWidth,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => widget.onOpen(feature.$1),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: cellWidth * .09,
                                    vertical: 3,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: cellWidth * .70,
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .85,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: _blue.withValues(
                                              alpha: .35,
                                            ),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF76BDF3)
                                                  .withValues(alpha: .12),
                                              blurRadius: 14,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: FaIcon(
                                          feature.$3,
                                          size: iconSize,
                                          color: feature.$4,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      SizedBox(
                                        height: labelSize * 2.8,
                                        child: Text(
                                          feature.$2,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: labelSize,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                          ),
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
