import 'package:flutter/material.dart';

import '../../../../core/routes/auth_gate.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../controllers/onboarding_controller.dart';
import '../../../../core/themes/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.preferences});

  final OnboardingRepository preferences;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _saving = false;

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await OnboardingController(widget.preferences).completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể lưu trạng thái. Vui lòng thử lại.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    size: 100,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chào mừng đến với HealWay',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gần hơn với sức khỏe của bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),
                  const ListTile(
                    leading: Icon(Icons.calendar_month_outlined),
                    title: Text('Đặt lịch khám thuận tiện'),
                    subtitle: Text(
                      'Chủ động sắp xếp thời gian chăm sóc sức khỏe.',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.medical_services_outlined),
                    title: Text('Kết nối với bác sĩ'),
                    subtitle: Text(
                      'Lựa chọn bác sĩ phù hợp với nhu cầu của bạn.',
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _complete,
                      child: Text(_saving ? 'Đang lưu...' : 'Bắt đầu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
