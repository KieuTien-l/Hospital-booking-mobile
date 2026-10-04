import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

const patientFunctions = <(String, String, FaIconData, Color)>[
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

const patientFunctionListIcons = <IconData>[
  Icons.add_circle_outline_rounded,
  Icons.calendar_month_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.folder_shared_outlined,
  Icons.assignment_outlined,
  Icons.headset_mic_outlined,
  Icons.menu_book_outlined,
  Icons.chat_bubble_outline_rounded,
];
