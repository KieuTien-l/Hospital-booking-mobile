import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/appointment_confirmation_ui_model.dart';
import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_status_badge.dart';
import 'payment_result_page.dart';

class PaymentProcessingPage extends StatelessWidget {
  const PaymentProcessingPage({
    super.key,
    required this.items,
    required this.method,
    this.isDemo = false,
  });
  final List<AppointmentConfirmationResult> items;
  final PaymentMethod method;
  final bool isDemo;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: method.label,
    isDemo: isDemo,
    children: [
      const PaymentStatusBadge(status: PaymentStatus.pending),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                method == PaymentMethod.bankQr
                    ? Icons.qr_code_2
                    : Icons.payments_outlined,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chưa kết nối cổng thanh toán. Không thực hiện chuyển tiền tại màn hình này.',
                textAlign: TextAlign.center,
              ),
              if (method == PaymentMethod.bankQr)
                const Text('Mã QR thanh toán sẽ được cung cấp khi tích hợp.'),
              if (isDemo) ...[
                const SizedBox(height: 16),
                const SelectableText('Nội dung mẫu: DEMO-HEALWAY'),
                TextButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Sao chép nội dung demo'),
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: 'DEMO-HEALWAY'),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung demo.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (isDemo) ...[
        const Text(
          'Mô phỏng kết quả — chỉ dùng để xem giao diện',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final status in PaymentStatus.values)
          OutlinedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PaymentResultPage(
                  payment: PaymentUiModel(
                    items: items,
                    method: method,
                    status: status,
                    isDemo: true,
                    transactionId: 'DEMO-PREVIEW',
                    timestamp: DateTime(2026, 10, 11, 9, 30),
                  ),
                ),
              ),
            ),
            child: Text('Demo: ${status.label}'),
          ),
      ],
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Quay lại chọn phương thức'),
      ),
    ],
  );
}
