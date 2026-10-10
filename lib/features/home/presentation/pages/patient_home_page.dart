import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../appointments/presentation/models/appointment_history_demo_data.dart';
import '../../../appointments/presentation/pages/appointment_history_page.dart';
import '../../../appointments/presentation/pages/select_appointment_date_page.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../../../profile/presentation/pages/create_patient_profile_page.dart';
import '../../../profile/presentation/pages/edit_profile_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../profile/presentation/pages/select_patient_profile_page.dart';
import '../../../profile/presentation/models/patient_profile_demo_data.dart';
import '../../../health_records/presentation/pages/health_records_page.dart';
import '../../../specialties/presentation/pages/specialty_list_page.dart';
import 'functions_page.dart';
import '../widgets/quick_functions_section.dart';
import '../widgets/featured_news_card.dart';
import '../widgets/other_functions_section.dart';
import '../widgets/patient_home_background.dart';
import '../widgets/patient_home_header.dart';

const _blue = Color(0xFF0065B8);
const _ink = Color(0xFF163958);

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

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
    if (title == 'Hồ sơ cá nhân') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const HealthRecordsPage()),
      );
      return;
    }
    if (title == 'Lịch đặt khám' || title == 'Lịch sử đặt khám') {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AppointmentHistoryPage(
            items: AppointmentHistoryDemoData.items,
            isDemo: true,
          ),
        ),
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
    if (title == 'Đặt khám') {
      FocusScope.of(context).unfocus();
      final navigator = Navigator.of(context);
      final homeRoute = ModalRoute.of(context);
      final profileController = context.read<PatientProfileController?>();
      final List<Patient> profiles = profileController == null
          ? PatientProfileDemoData.profiles
          : profileController.patient == null
          ? const <Patient>[]
          : <Patient>[profileController.patient!];
      void returnHome() {
        navigator.popUntil((route) => route == homeRoute);
        setState(() {
          _tab = 0;
          _query = '';
        });
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
                content ??
                    'Chức năng đang được hoàn thiện. Vui lòng quay lại sau.',
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
    final candidate = context.watch<PatientProfileController?>()?.patient;
    final patient = user != null && candidate?.authUserId == user.id
        ? candidate
        : null;
    String value(String? profileValue, String? authValue) =>
        profileValue != null && profileValue.trim().isNotEmpty
        ? profileValue
        : authValue ?? '';
    if (user == null) {
      return ProfilePage(
        onOpen: _open,
        onLogout: () => auth.logout(),
        isLoggingOut: auth.isLoading,
      );
    }
    return ProfilePage(
      fullName: value(patient?.fullName, user.fullName),
      email: value(patient?.email, user.email),
      phone: value(patient?.phone, user.phone),
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
