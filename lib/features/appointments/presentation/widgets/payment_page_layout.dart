import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';

class PaymentPageLayout extends StatelessWidget {
  const PaymentPageLayout({
    super.key,
    required this.title,
    required this.children,
    this.bottom,
    this.isDemo = false,
  });
  final String title;
  final List<Widget> children;
  final Widget? bottom;
  final bool isDemo;
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
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isDemo)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'CHẾ ĐỘ DEMO • Không phát sinh thanh toán hoặc lịch hẹn thật.',
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...children,
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: bottom,
      ),
    ),
  );
}
