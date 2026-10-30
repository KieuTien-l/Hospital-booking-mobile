import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../appointments/presentation/pages/patient_appointments_page.dart';
import '../../../appointments/presentation/pages/select_appointment_date_page.dart';
import '../../../appointments/presentation/pages/payment_history_page.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/pages/forgot_password_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../../../profile/presentation/pages/create_patient_profile_page.dart';
import '../../../profile/presentation/pages/edit_profile_page.dart';
import '../../../profile/presentation/pages/patient_clinical_results_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../profile/presentation/pages/select_patient_profile_page.dart';
import '../../../profile/presentation/models/patient_profile_demo_data.dart';
import '../../../health_records/presentation/pages/health_records_page.dart';
import '../../../specialties/presentation/pages/specialty_list_page.dart';
import 'functions_page.dart';
import 'usage_guide_page.dart';
import 'customer_feedback_page.dart';
import '../../../chatbot/presentation/pages/chatbot_page.dart';
import 'patient_support_page.dart';
import '../widgets/quick_functions_section.dart';
import '../widgets/featured_news_card.dart';
import '../widgets/other_functions_section.dart';
import '../widgets/patient_home_background.dart';
import '../widgets/patient_home_header.dart';

const _blue = Color(0xFF0065B8);
const _ink = Color(0xFF163958);

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, this.useLiveCommunications = false});
  final bool useLiveCommunications;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().currentUser;
      if (user != null) {
        context.read<PatientProfileController?>()?.watchPatient(user.id);
      }
    });
  }

  void _open(String title, [String? content]) {
    if (title == 'Hỏi - đáp (Chatbot)') {
      FocusScope.of(context).unfocus();
      Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const ChatbotPage()));
      return;
    }
    if (title == 'Lắng nghe khách hàng') {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const CustomerFeedbackPage()),
      );
      return;
    }
    if (title == 'Hướng dẫn sử dụng') {
      FocusScope.of(context).unfocus();
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const UsageGuidePage()));
      return;
    }
    if (title == 'Thanh toán viện phí') {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PaymentHistoryPage()),
      );
      return;
    }
    if (title == 'Thông tin bệnh nhân') {
      final profileController = context.read<PatientProfileController?>();
      if (profileController?.isLoading == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải hồ sơ bệnh nhân...')),
        );
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => profileController?.patient == null
              ? const CreatePatientProfilePage()
              : const EditProfilePage(),
        ),
      );
      return;
    }
    if (title == 'Đổi mật khẩu') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
      );
      return;
    }
    if (title == 'Cài đặt') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PatientSupportPage(kind: PatientSupportKind.settings),
        ),
      );
      return;
    }
    if (title == 'Chính sách & điều khoản') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PatientSupportPage(kind: PatientSupportKind.policy),
        ),
      );
      return;
    }
    if (title == 'Hướng dẫn khách hàng') {
      Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const UsageGuidePage()));
      return;
    }
    if (title == 'Liên hệ' || title == 'Liên hệ / Hỗ trợ') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PatientSupportPage(kind: PatientSupportKind.contact),
        ),
      );
      return;
    }
    if (title == 'Bảng giá dịch vụ kỹ thuật') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              const PatientSupportPage(kind: PatientSupportKind.servicePrices),
        ),
      );
      return;
    }
    if (title == 'Hồ sơ cá nhân') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const HealthRecordsPage()),
      );
      return;
    }
    if (title == 'Lịch đặt khám' || title == 'Lịch sử đặt khám') {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const PatientAppointmentsPage()),
      );
      return;
    }
    if (title == 'Hồ sơ sức khỏe') {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const HealthRecordsPage()),
      );
      return;
    }
    if (title == 'Kết quả cận lâm sàng') {
      FocusScope.of(context).unfocus();
      final profileController = context.read<PatientProfileController?>();
      if (profileController?.isLoading == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tải hồ sơ bệnh nhân...')),
        );
        return;
      }
      final patient = profileController?.patient;
      if (patient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Vui lòng cập nhật hồ sơ bệnh nhân để xem kết quả cận lâm sàng.',
            ),
          ),
        );
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PatientClinicalResultsPage(patient: patient),
        ),
      );
      return;
    }
    if (title == 'Đặt khám') {
      FocusScope.of(context).unfocus();
      final navigator = Navigator.of(context);
      final homeRoute = ModalRoute.of(context);
      final profileController = context.read<PatientProfileController?>();
      final List<Patient> profiles = profileController == null
          ? PatientProfileDemoData.profiles
          : profileController.patients;
      void returnHome() {
        navigator.popUntil((route) => route == homeRoute);
        setState(() {
          _tab = 0;
          _query = '';
        });
      }

      if (profileController != null && profiles.isEmpty) {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bạn đã từng khám tại bệnh viện?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 22),
                  _ProfileEntryOption(
                    icon: Icons.badge_outlined,
                    title: 'ĐÃ TỪNG KHÁM, NHẬP MÃ NGƯỜI BỆNH',
                    subtitle: 'Tìm và liên kết hồ sơ đã có trong hệ thống',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tra cứu hồ sơ bệnh viện sẽ khả dụng khi kết nối API bệnh viện.',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ProfileEntryOption(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'CHƯA TỪNG KHÁM, TẠO HỒ SƠ MỚI',
                    subtitle: 'Đăng ký hồ sơ cho lần khám đầu tiên',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      navigator.push<void>(
                        MaterialPageRoute(
                          builder: (_) => const CreatePatientProfilePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ),
        );
        return;
      }

      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => SelectPatientProfilePage(
            profiles: profiles,
            isDemo: profileController == null,
            onProfileSelected: (patient) {
              // Keep the selected profile in the presentation route for later integration.
              navigator.push<void>(
                MaterialPageRoute(
                  settings: RouteSettings(arguments: patient),
                  builder: (_) => SpecialtyListPage(
                    onSpecialtySelected: (specialty) => navigator.push<void>(
                      MaterialPageRoute(
                        settings: RouteSettings(arguments: patient),
                        builder: (_) => SelectAppointmentDatePage(
                          specialty: specialty,
                          onHome: returnHome,
                          useDemoData: profileController == null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            onHome: returnHome,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                content ?? 'Chưa có nội dung hướng dẫn cho mục này.',
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _functions() => QuickFunctionsSection(
    query: _query,
    onQueryChanged: (value) => setState(() => _query = value),
    onOpen: _open,
  );

  Widget _news(String title, String imageAsset) => FeaturedNewsCard(
    title: title,
    imageAsset: imageAsset,
    onTap: () => _open(
      title,
      'Nội dung minh họa cho giao diện HealWay. Tin tức chính thức sẽ được cập nhật khi kết nối dữ liệu bệnh viện.',
    ),
  );

  Widget _home() => SingleChildScrollView(
    key: const PageStorageKey('patient-home'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PatientHomeHeader(),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _blue.withValues(alpha: .08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _functions(),
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 18),
              child: Text(
                'Tin tức nổi bật',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0753AB),
                ),
              ),
            ),
            _news(
              'Cùng tham gia cuộc thi tìm hiểu quy định pháp luật về phòng, chống tác hại của thuốc lá',
              'assets/images/news/healthcare.jpg',
            ),
            const SizedBox(height: 8),
            _news(
              'Thông báo về việc tìm chủ sở hữu của tài sản là tiền mặt do người bệnh/thân nhân để quên',
              'assets/images/news/hospital.jpg',
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 26, bottom: 14),
          child: Text(
            'Chức năng khác',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0753AB),
            ),
          ),
        ),
        OtherFunctionsSection(onOpen: _open),
      ],
    ),
  );

  Widget _body(AuthController auth) {
    if (_tab == 0) return _home();
    if (_tab == 2) return FunctionsPage(onOpen: _open);
    final user = auth.currentUser;
    if (user == null) {
      return ProfilePage(
        onOpen: _open,
        onLogout: () => auth.logout(),
        isLoggingOut: auth.isLoading,
      );
    }
    return ProfilePage(
      // This tab represents the signed-in app account. The selected patient
      // can be a parent or child, and must not replace the account identity.
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      onOpen: _open,
      onLogout: () => auth.logout(),
      isLoggingOut: auth.isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F8FC),
        body: PatientHomeBackground(
          child: ColoredBox(
            color: _tab == 1 || _tab == 2 ? Colors.white : Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_tab != 1) _body(auth),
                      Offstage(
                        offstage: _tab != 1,
                        child: const NotificationsPage(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE6E8EC))),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 13,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: states.contains(WidgetState.selected)
                      ? _blue
                      : const Color(0xFF1B2B38),
                ),
              ),
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(size: 28, color: Color(0xFF1B2B38)),
              ),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) => setState(() {
                _tab = value;
                _query = '';
              }),
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFDCEFFA),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: _blue),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications, color: _blue),
                  label: 'Thông báo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.layers_outlined),
                  selectedIcon: Icon(Icons.layers_rounded, color: _blue),
                  label: 'Chức năng',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle, color: _blue),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileEntryOption extends StatelessWidget {
  const _ProfileEntryOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF2FF),
        child: Icon(icon, color: _blue),
      ),
      title: Text(
        title,
        style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right, color: _blue),
    ),
  );
}
