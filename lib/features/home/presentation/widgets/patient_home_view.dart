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

class PatientHomeView extends StatefulWidget {
  const PatientHomeView({
    super.key,
    this.fullName = '',
    this.email = '',
    required this.onLogout,
  });
  final String fullName;
  final String email;
  final VoidCallback onLogout;
  @override
  State<PatientHomeView> createState() => _PatientHomeViewState();
}

class _PatientHomeViewState extends State<PatientHomeView> {
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

  Widget _functions() {
    final matches = _features
        .where((f) => f.$1.toLowerCase().contains(_query.trim().toLowerCase()))
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
                onChanged: (value) => setState(() => _query = value),
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
                                onTap: () => _open(f.$1),
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

  Widget _news(String title, IconData icon, Color color) => SizedBox(
    width: 270,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(
          title,
          'Nội dung minh họa cho giao diện HealWay. Tin tức chính thức sẽ được cập nhật khi kết nối dữ liệu bệnh viện.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 116),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: .65)],
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'HEALWAY',
                          style: TextStyle(
                            color: Colors.white,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Đồng hành cùng\nsức khỏe của bạn',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, size: 58, color: Colors.white),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THÔNG TIN THAM KHẢO',
                    style: TextStyle(
                      fontSize: 10,
                      color: _blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khám phá thêm  →',
                    style: TextStyle(fontSize: 12, color: _blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        const Center(
          child: Text(
            'Chào mừng đến với',
            style: TextStyle(fontSize: 15, color: Color(0xFF54768D)),
          ),
        ),
        const SizedBox(height: 5),
        const Center(
          child: Text(
            'Bệnh viện Quốc tế Meridian',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Image.asset(
            'assets/images/name_logo.png',
            width: 220,
            height: 74,
            fit: BoxFit.contain,
            semanticLabel: 'HealWay',
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Ứng dụng dành cho bệnh nhân',
            style: TextStyle(color: Color(0xFF54768D), fontSize: 14),
          ),
        ),
        const SizedBox(height: 28),
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
        _section(
          'Tin tức nổi bật',
          action: TextButton(
            onPressed: () => _open(
              'Tin tức nổi bật',
              'Tin tức trên trang chủ là nội dung minh họa. Tin tức chính thức của bệnh viện sẽ được cập nhật sau.',
            ),
            child: const Text('Xem tất cả'),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _news(
                'Chủ động đặt khám, an tâm mỗi ngày',
                Icons.medical_services_outlined,
                const Color(0xFF087CAF),
              ),
              const SizedBox(width: 14),
              _news(
                'Hồ sơ sức khỏe trong tầm tay',
                Icons.favorite_border,
                const Color(0xFF269D94),
              ),
            ],
          ),
        ),
        _section('Dịch vụ nổi bật'),
        _service(
          'Bảng giá dịch vụ kỹ thuật',
          'Tra cứu thông tin chi phí dịch vụ',
          Icons.receipt_long_outlined,
        ),
        _service(
          'Hướng dẫn khách hàng',
          'Chuẩn bị cho hành trình thăm khám',
          Icons.explore_outlined,
        ),
        _service(
          'Liên hệ',
          'Kết nối với Bệnh viện Quốc tế Meridian',
          Icons.phone_in_talk_outlined,
        ),
      ],
    ),
  );

  Widget _body() {
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
            widget.fullName.isEmpty ? 'Bệnh nhân' : widget.fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _ink,
            ),
          ),
          if (widget.email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(widget.email),
            ),
          const SizedBox(height: 28),
          _service(
            'Hồ sơ sức khỏe',
            'Thông tin sức khỏe cá nhân',
            Icons.folder_shared_outlined,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F8FC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCEFFA), Color(0xFFF4F9FC), Color(0xFFE8F6F5)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _body(),
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
