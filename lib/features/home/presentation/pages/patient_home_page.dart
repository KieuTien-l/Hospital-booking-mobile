import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
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

  void _open(String title, [String? content]) => showModalBottomSheet<void>(
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

  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );

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

  Widget _service(String title, String subtitle, IconData icon) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FC),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: _blue),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: _ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7791A7)),
      ),
      trailing: const Icon(Icons.chevron_right, color: _blue),
      onTap: () => _open(title),
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
    final fullName = auth.currentUser?.fullName ?? '';
    final email = auth.currentUser?.email ?? '';
    if (_tab == 0) return _home();
    if (_tab == 2) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [_section('Chức năng'), _functions()]),
      );
    }
    if (_tab == 1) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_rounded, size: 64, color: _blue),
              SizedBox(height: 16),
              Text(
                'Thông báo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              SizedBox(height: 8),
              Text('Bạn chưa có thông báo mới.'),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFDCEFFA),
            child: Icon(Icons.person_outline, size: 46, color: _blue),
          ),
          const SizedBox(height: 16),
          Text(
            fullName.isEmpty ? 'Bệnh nhân' : fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          if (email.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(email)),
          const SizedBox(height: 28),
          _service(
            'Hồ sơ sức khỏe',
            'Thông tin sức khỏe cá nhân',
            Icons.folder_shared_outlined,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
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
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _body(auth),
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
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
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded, color: _blue),
              label: 'Chức năng',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: _blue),
              label: 'Cá nhân',
            ),
          ],
        ),
      ),
    );
  }
}
