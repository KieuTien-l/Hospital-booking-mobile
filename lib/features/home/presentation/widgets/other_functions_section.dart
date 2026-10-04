import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const _blue = Color(0xFF0753AB);
const _features = <(String, String, Object, Color)>[
  (
    'Bảng giá dịch vụ kỹ thuật',
    'Bảng giá\ndịch vụ',
    FontAwesomeIcons.moneyBill1,
    Color(0xFF1685FF),
  ),
  (
    'Hướng dẫn khách hàng',
    'Hướng dẫn\nkhách hàng',
    Icons.menu_book_outlined,
    Color(0xFF05BF96),
  ),
  ('Liên hệ', 'Liên hệ', Icons.phone_outlined, Color(0xFFFF822D)),
];

class OtherFunctionsSection extends StatelessWidget {
  const OtherFunctionsSection({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cellWidth = constraints.maxWidth / 3;
      final cardSize = (cellWidth * .64).clamp(48.0, 82.0);
      final iconSize = (cardSize * .40).clamp(20.0, 32.0);
      final labelSize = (cellWidth * .12).clamp(11.0, 14.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _features
            .map(
              (feature) => Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onOpen(feature.$1),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: cellWidth * .09,
                        vertical: 3,
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: cardSize,
                            width: cardSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _blue.withValues(alpha: .35),
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
                            child: feature.$3 is FaIconData
                                ? FaIcon(
                                    feature.$3 as FaIconData,
                                    size: iconSize,
                                    color: feature.$4,
                                  )
                                : Icon(
                                    feature.$3 as IconData,
                                    size: iconSize,
                                    color: feature.$4,
                                  ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            feature.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: labelSize,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
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
  );
}
