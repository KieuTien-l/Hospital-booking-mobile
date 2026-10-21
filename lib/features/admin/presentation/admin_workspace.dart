import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/utils/model_value_parser.dart';
import '../../appointments/domain/entities/appointment.dart';
import '../../home/presentation/widgets/patient_home_background.dart';
import '../data/admin_doctor_provisioner.dart';
import '../data/admin_repository.dart';
import 'controllers/admin_account_controller.dart';
import 'controllers/admin_appointment_controller.dart';
import 'controllers/admin_dashboard_controller.dart';
import '../data/admin_commands.dart';
import 'admin_editor.dart';
import 'admin_controller.dart';
import 'admin_metrics.dart';
import 'admin_sections.dart';

part 'admin_dashboard.dart';
part 'admin_actions.dart';
part 'admin_reports.dart';

const _blue = Color(0xFF0864CA);
const _ink = Color(0xFF193D65);
const _muted = Color(0xFF6383A4);
const _line = Color(0xFFDCECF8);
const _navigationItems = [
  0,
  18,
  1,
  5,
  6,
  2,
  4,
  3,
  7,
  16,
  8,
  12,
  9,
  17,
  10,
  11,
  13,
  14,
  15,
];
const _navigationGroups = {
  0: 'TỔNG QUAN',
  1: 'ĐIỀU HÀNH KHÁM',
  2: 'DANH MỤC',
  7: 'TÀI CHÍNH & CHĂM SÓC',
  9: 'QUẢN TRỊ',
  10: 'TRA CỨU MỞ RỘNG',
  14: 'HỆ THỐNG',
};

class _AdminSectionBackdrop extends StatelessWidget {
  const _AdminSectionBackdrop({required this.padding, required this.child});
  final double padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        top: -padding,
        bottom: -padding,
        left: -padding,
        right: -padding,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.transparent,
                Colors.transparent,
              ],
              stops: [0, .5, .5, 1],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class AdminWorkspace extends StatefulWidget {
  const AdminWorkspace({
    super.key,
    required this.userName,
    required this.onLogout,
    this.repository,
    this.commands,
    this.doctorProvisioner,
  });
  final String userName;
  final VoidCallback onLogout;
  final AdminRepository? repository;
  final AdminCommands? commands;
  final DoctorAccountProvisioner? doctorProvisioner;

  @override
  State<AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<AdminWorkspace> {
  late final AdminController _controller;
  late final AdminCommands? _commands;
  late final DoctorAccountProvisioner _doctorProvisioner;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;
  int _page = 0;
  String _status = 'Tất cả';
  DateTime? _date;
  DateTimeRange? _period;
  String _periodPreset = 'today';
  DateTimeRange? _listPeriod;
  DateTimeRange? _reportPeriod;
  String _doctor = 'Tất cả';
  String _specialty = 'Tất cả';
  String _scheduleView = 'Danh sách';
  final Map<int, _AdminViewState> _views = {};
  final Set<String> _demoPreviews = {};

  @override
  void initState() {
    super.initState();
    _commands =
        widget.commands ??
        (widget.repository == null ? FirebaseAdminCommands() : null);
    _doctorProvisioner =
        widget.doctorProvisioner ?? FirebaseDoctorAccountProvisioner();
    _controller = AdminController(
      widget.repository ?? FirestoreAdminRepository(),
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_commands is FirebaseAdminCommands) {
      (_commands).dispose();
    }
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    _views[_selected] = _AdminViewState(
      _search.text,
      _status,
      _date,
      _page,
      _doctor,
      _specialty,
      _listPeriod,
    );
    setState(() {
      _selected = index;
      final view = _views[index];
      _search.text = view?.query ?? '';
      _status = view?.status ?? 'Tất cả';
      _date = view?.date;
      _page = view?.page ?? 0;
      _doctor = view?.doctor ?? 'Tất cả';
      _specialty = view?.specialty ?? 'Tất cả';
      _listPeriod = view?.period;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  ThemeData _adminTheme(BuildContext context) => Theme.of(context).copyWith(
    colorScheme: Theme.of(context).colorScheme.copyWith(
      primary: _blue,
      onPrimary: Colors.white,
      secondary: const Color(0xFF20B0EE),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        side: const BorderSide(color: Color(0xFFACD2EF)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _blue),
    ),
    inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
      filled: true,
      fillColor: const Color(0xFFF5FBFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.4),
      ),
    ),
    chipTheme: Theme.of(context).chipTheme.copyWith(
      backgroundColor: const Color(0xFFF5FBFF),
      selectedColor: const Color(0xFFDDEFFF),
      side: const BorderSide(color: _line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 12,
        color: _ink,
      ),
    ),
    textTheme: Theme.of(context).textTheme
        .apply(fontFamily: 'BeVietnamPro', bodyColor: _ink, displayColor: _ink),
    scaffoldBackgroundColor: Colors.transparent,
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: _adminTheme(context),
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 1100;
          return PatientHomeBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              drawer: wide
                  ? null
                  : Drawer(child: _navigation(closeDrawer: true)),
              appBar: wide
                  ? null
                  : AppBar(
                      backgroundColor: Colors.transparent,
                      title: const Text(
                        'HealWay Admin',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      actions: [
                        IconButton(
                          tooltip: 'Đăng xuất',
                          onPressed: widget.onLogout,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
              body: SafeArea(
                child: Row(
                  children: [
                    if (wide) SizedBox(width: 245, child: _navigation()),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 30 : 16,
                              vertical: 14,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Color(0xFFB3D8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  adminSections[_selected].icon,
                                  color: _blue,
                                  size: 25,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    adminSections[_selected].title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scroll,
                              padding: EdgeInsets.all(wide ? 30 : 16),
                              child: _selected == 0
                                  ? _overview(wide)
                                  : _section(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _navigation({bool closeDrawer = false}) => Builder(
    builder: (context) => Material(
      color: const Color(0xF5FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 20, 25),
            child: Row(
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF20B0EE),
                  size: 36,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HealWay',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'KHÔNG GIAN QUẢN TRỊ',
                      style: TextStyle(
                        fontSize: 9,
                        color: _muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _navigationItems.length,
              itemBuilder: (context, position) {
                final index = _navigationItems[position];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_navigationGroups.containsKey(index))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 20, 4, 8),
                        child: Text(
                          _navigationGroups[index]!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        selected: index == _selected,
                        selectedColor: _blue,
                        selectedTileColor: const Color(0xFFDFF1FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          adminSections[index].icon,
                          size: 21,
                          color: index == _selected ? _blue : _muted,
                        ),
                        title: Text(
                          adminSections[index].title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () {
                          _select(index);
                          if (closeDrawer) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: _muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chế độ xem & tra cứu',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, size: 20),
            title: const Text('Đăng xuất'),
            onTap: widget.onLogout,
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  Widget _overview(bool wide) => _AdminDashboard(
    contentPadding: wide ? 30 : 16,
    controller: _controller,
    userName: widget.userName,
    period: _period,
    periodPreset: _periodPreset,
    onPeriodChanged: (preset, value) => setState(() {
      _periodPreset = preset;
      _period = value;
    }),
    onNavigate: _navigateFromOverview,
    onDetail: (index, record) => _detail(adminSections[index], record, false),
  );

  void _navigateFromOverview(
    int index, {
    String? status,
    DateTimeRange? period,
  }) {
    _select(index);
    setState(() {
      _status = status ?? 'Tất cả';
      _date = null;
      _search.clear();
      _doctor = 'Tất cả';
      _specialty = 'Tất cả';
      _page = 0;
      _listPeriod = period;
    });
  }

  Widget _section() {
    final section = adminSections[_selected];
    if (_selected == 14) return _settingsPanel();
    if (_selected == 18) return _reportsPanel();
    if (section.collection == null) return _settings();
    final dataset = _controller.dataset(section.collection!);
    final accountController = section.collection == 'TAI_KHOAN'
        ? context.watch<AdminAccountController?>()
        : null;
    final appointmentController = section.collection == 'LICH_HEN'
        ? context.watch<AdminAppointmentController?>()
        : null;
    if (dataset.loading) {
      return _panel(
        section.title,
        'Đang kết nối Firebase',
        const LinearProgressIndicator(),
      );
    }
    if (dataset.error != null && !_demoPreviews.contains(section.collection)) {
      return _panel(
        section.title,
        'Chưa đọc được dữ liệu',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _notice(dataset.error!, error: true),
            const SizedBox(height: 16),
            const Text(
              'Không thể xác định dữ liệu hiện tại. Dữ liệu demo không thay thế kết quả lỗi truy cập.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _controller.retry(section.collection!),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _demoPreviews.add(section.collection!)),
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Xem giao diện DEMO'),
            ),
          ],
        ),
      );
    }
    final demo = dataset.error != null || dataset.useDemo;
    final records = demo ? adminDemoRecords(section) : dataset.records;
    final statuses =
        records
            .map(
              (r) => readString(
                _selected == 8
                    ? r.data['processingStatus'] ?? 'NEW'
                    : r.data['status'],
              ),
            )
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (section.collection == 'LICH_LAM_VIEC') {
      for (final status in ['ACTIVE', 'INACTIVE']) {
        if (!statuses.contains(status)) statuses.add(status);
      }
      statuses.sort();
    }
    if (_status != 'Tất cả' &&
        _status != 'Đã thu' &&
        !statuses.contains(_status)) {
      statuses.add(_status);
    }
    final selectedStatus = _status;
    final query = _search.text.trim().toLowerCase();
    final filtered = records.where((r) {
      if (_status == 'Đã thu' &&
          !{'PAID', 'SUCCESS'}.contains(adminStatus(r.data['status']))) {
        return false;
      }
      if (_status != 'Đã thu' &&
          _status != 'Tất cả' &&
          readString(
                _selected == 8
                    ? r.data['processingStatus'] ?? 'NEW'
                    : r.data['status'],
              ) !=
              _status) {
        return false;
      }
      final dateField = _selected == 7
          ? 'paidAt'
          : _selected == 5
          ? 'workDate'
          : 'appointmentDate';
      if (_listPeriod != null &&
          !adminInPeriod(
            r.data[dateField],
            _listPeriod!.start,
            _listPeriod!.end,
          )) {
        return false;
      }
      if (_doctor != 'Tất cả' &&
          readReferenceId(r.data['doctorId']) != _doctor) {
        return false;
      }
      if (_specialty != 'Tất cả') {
        var specialtyId = readReferenceId(r.data['specialtyId']);
        if (specialtyId.isEmpty) {
          for (final doctor in _controller.dataset('BAC_SI').records) {
            if (doctor.id == readReferenceId(r.data['doctorId'])) {
              specialtyId = readReferenceId(doctor.data['specialtyId']);
            }
          }
        }
        if (specialtyId != _specialty) return false;
      }
      if (_date != null &&
          !_sameDate(r.data['appointmentDate'] ?? r.data['workDate'], _date!)) {
        return false;
      }
      return query.isEmpty ||
          [
            r.id,
            ...r.data.entries.map((e) => _format(e.key, e.value)),
            for (final patient in _controller.dataset('BENH_NHAN').records)
              if (patient.id == readReferenceId(r.data['patientId']))
                readString(patient.data['phone']),
          ].join(' ').toLowerCase().contains(query);
    }).toList()..sort((a, b) => a.id.compareTo(b.id));
    final pages = math.max(1, (filtered.length / 10).ceil());
    final page = math.min(_page, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionIntro(section, dataset),
        const SizedBox(height: 18),
        if (accountController != null) ...[
          _pendingAccountsPanel(accountController),
          const SizedBox(height: 18),
        ],
        if (appointmentController != null) ...[
          _appointmentAuditPanel(appointmentController),
          const SizedBox(height: 18),
        ],
        if (_createButton(section) != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _createButton(section),
          ),
          const SizedBox(height: 16),
        ],
        if (dataset.error != null) ...[
          _notice(
            '${dataset.error!} Bạn đang xem DEMO theo yêu cầu, không phải dữ liệu Firebase.',
            error: true,
          ),
          TextButton(
            onPressed: () =>
                setState(() => _demoPreviews.remove(section.collection)),
            child: const Text('Quay lại trạng thái kết nối'),
          ),
          const SizedBox(height: 12),
        ],
        if (demo)
          _notice(
            dataset.error != null
                ? 'DEMO · Chưa xác minh được dữ liệu ${section.collection}. Bản ghi minh họa không lưu Firebase.'
                : 'DEMO · Collection ${section.collection} chưa có bản ghi. Dữ liệu bên dưới chỉ minh họa và không lưu Firebase.',
          ),
        if (demo) const SizedBox(height: 18),
        _panel(
          'Danh sách ${section.title.toLowerCase()}',
          '${demo ? '1 bản ghi minh họa' : '${dataset.records.length} bản ghi trên Firebase'} · Chọn dòng để xem chi tiết',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selected == 1) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final status in [
                      'Tất cả',
                      'PENDING',
                      'CONFIRMED',
                      'COMPLETED',
                      'CANCELLED',
                      'NO_SHOW',
                    ])
                      ChoiceChip(
                        label: Text(_statusText(status)),
                        selected: _status == status,
                        onSelected: (_) => setState(() {
                          _status = status;
                          _page = 0;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              _filterSurface(
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: math.min(360, box.maxWidth),
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            hintText: 'Tìm tên, mã, số điện thoại…',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() => _page = 0),
                        ),
                      ),
                      if (statuses.isNotEmpty)
                        SizedBox(
                          width: box.maxWidth < 600 ? box.maxWidth : 220,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: ValueKey('$_selected-$_status'),
                            initialValue: _status == 'Đã thu'
                                ? 'Đã thu'
                                : selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Trạng thái',
                            ),
                            items:
                                [
                                      'Tất cả',
                                      if (_selected == 7) 'Đã thu',
                                      ...statuses,
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          _statusText(s),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) => setState(() {
                              _status = value ?? 'Tất cả';
                              _page = 0;
                            }),
                          ),
                        ),
                      if ([1, 5, 6].contains(_selected))
                        _referenceFilter(
                          'Bác sĩ',
                          'BAC_SI',
                          _doctor,
                          (v) => setState(() {
                            _doctor = v;
                            _page = 0;
                          }),
                          width: box.maxWidth < 600 ? box.maxWidth : 220,
                        ),
                      if ([1, 2, 5].contains(_selected))
                        _referenceFilter(
                          'Chuyên khoa',
                          'CHUYEN_KHOA',
                          _specialty,
                          (v) => setState(() {
                            _specialty = v;
                            _page = 0;
                          }),
                          width: box.maxWidth < 600 ? box.maxWidth : 220,
                        ),
                      if ([1, 5].contains(_selected))
                        OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              useRootNavigator: false,
                              builder: (context, child) => Theme(
                                data: _adminTheme(context),
                                child: child!,
                              ),
                              initialDate: _date ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && mounted) {
                              setState(() {
                                _date = date;
                                _page = 0;
                              });
                            }
                          },
                          icon: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _date == null ? 'Lọc ngày' : _dateText(_date!),
                          ),
                        ),
                      if (_date != null)
                        IconButton(
                          tooltip: 'Bỏ lọc ngày',
                          onPressed: () => setState(() => _date = null),
                          icon: const Icon(Icons.close),
                        ),
                      if (_listPeriod != null)
                        InputChip(
                          label: Text(
                            '${_dateText(_listPeriod!.start)} – ${_dateText(_listPeriod!.end)}',
                          ),
                          onDeleted: () => setState(() {
                            _listPeriod = null;
                            _page = 0;
                          }),
                        ),
                      if (_search.text.isNotEmpty ||
                          _status != 'Tất cả' ||
                          _date != null ||
                          _doctor != 'Tất cả' ||
                          _specialty != 'Tất cả' ||
                          _listPeriod != null)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _search.clear();
                            _status = 'Tất cả';
                            _date = null;
                            _listPeriod = null;
                            _doctor = 'Tất cả';
                            _specialty = 'Tất cả';
                            _page = 0;
                          }),
                          icon: const Icon(
                            Icons.filter_alt_off_outlined,
                            size: 17,
                          ),
                          label: const Text('Xóa bộ lọc'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_selected == 5) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final view in ['Danh sách', 'Theo ngày'])
                      ChoiceChip(
                        label: Text(view),
                        selected: _scheduleView == view,
                        onSelected: (_) => setState(() => _scheduleView = view),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('Không có kết quả phù hợp.'),
                )
              else if (_selected == 5 && _scheduleView == 'Theo ngày')
                _scheduleDays(filtered.skip(page * 10).take(10).toList(), demo)
              else if (_selected == 2)
                _doctorCards(filtered.skip(page * 10).take(10).toList(), demo)
              else
                _table(
                  section,
                  filtered.skip(page * 10).take(10).toList(),
                  demo: demo,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filtered.length} kết quả · Trang ${page + 1}/$pages',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Trang trước',
                    onPressed: page > 0
                        ? () => setState(() => _page = page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Trang sau',
                    onPressed: page + 1 < pages
                        ? () => setState(() => _page = page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingAccountsPanel(AdminAccountController controller) {
    final accounts = controller.pendingAccounts;
    return _panel(
      'Tài khoản chờ duyệt',
      controller.isLoading
          ? 'Đang tải danh sách từ Firestore'
          : '${accounts.length} tài khoản cần admin xử lý',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.hasError) ...[
            _notice(
              controller.errorMessage ?? 'Không tải được tài khoản chờ duyệt.',
              error: true,
            ),
            const SizedBox(height: 8),
          ],
          if (controller.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (accounts.isEmpty)
            const Text('Không có tài khoản nào đang chờ duyệt.')
          else
            for (final account in accounts.take(10))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: _blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              account.email,
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: controller.isLoading
                            ? null
                            : () => _reviewPendingAccount(
                                controller,
                                account.id,
                                approved: false,
                              ),
                        child: const Text('Từ chối'),
                      ),
                      FilledButton(
                        onPressed: controller.isLoading
                            ? null
                            : () => _reviewPendingAccount(
                                controller,
                                account.id,
                                approved: true,
                              ),
                        child: const Text('Duyệt'),
                      ),
                    ],
                  ),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.isLoading
                  ? null
                  : controller.loadPendingAccounts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Làm mới danh sách'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewPendingAccount(
    AdminAccountController controller,
    String accountId, {
    required bool approved,
  }) async {
    final saved = approved
        ? await controller.approveAccount(accountId)
        : await controller.rejectAccount(accountId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? controller.errorMessage ?? 'Không thể cập nhật tài khoản.'
              : approved
              ? 'Đã duyệt tài khoản.'
              : 'Đã từ chối tài khoản.',
        ),
      ),
    );
  }

  AppointmentStatus? _appointmentStatusFor(String value) => switch (value) {
    'PENDING' => AppointmentStatus.pending,
    'CONFIRMED' => AppointmentStatus.confirmed,
    'COMPLETED' => AppointmentStatus.completed,
    'CANCELLED' => AppointmentStatus.cancelled,
    'NO_SHOW' => AppointmentStatus.noShow,
    _ => null,
  };

  Widget _appointmentAuditPanel(AdminAppointmentController controller) {
    final invalid = controller.invalidRelationshipRecords;
    return _panel(
      'Kiểm tra quan hệ lịch hẹn',
      controller.isLoading
          ? 'Đang đối chiếu lịch hẹn, ca khám, lịch làm việc và bác sĩ'
          : '${controller.records.length} lịch hẹn đã được kiểm tra',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.hasError)
            _notice(
              controller.errorMessage ?? 'Không thể kiểm tra quan hệ lịch hẹn.',
              error: true,
            )
          else if (invalid.isEmpty && !controller.isLoading)
            const Text('Không phát hiện liên kết lịch hẹn sai.')
          else if (invalid.isNotEmpty)
            Text(
              'Cần kiểm tra ${invalid.length} lịch hẹn: ${invalid.take(5).map((item) => item.appointment.id).join(', ')}',
              style: const TextStyle(color: AppColors.error),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: controller.isLoading
                ? null
                : () => controller.load(
                    force: true,
                    filter: AdminAppointmentFilter(
                      status: _appointmentStatusFor(_status),
                      doctorId: _doctor == 'Tất cả' ? null : _doctor,
                      specialtyId: _specialty == 'Tất cả' ? null : _specialty,
                      date: _date,
                    ),
                  ),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Lọc và kiểm tra bằng backend'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReportPeriod() async {
    final range = await showDateRangePicker(
      context: context,
      useRootNavigator: false,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _reportPeriod,
      builder: (context, child) =>
          Theme(data: _adminTheme(context), child: child!),
    );
    if (range != null && mounted) setState(() => _reportPeriod = range);
  }

  Widget _sectionIntro(AdminSection section, AdminDataset dataset) {
    final descriptions = {
      1: 'Theo dõi lịch khám, tra cứu bệnh nhân và xem thông tin từng cuộc hẹn.',
      2: 'Kết nối đội ngũ bác sĩ, chuyên khoa và lịch khám tại một nơi.',
      3: 'Tra cứu hồ sơ bệnh nhân và lịch sử thông tin có liên quan.',
      4: 'Danh mục chuyên khoa và đội ngũ bác sĩ trực thuộc.',
      5: 'Theo dõi lịch làm việc và xem các ca khám thuộc từng lịch.',
      6: 'Theo dõi sức chứa và số chỗ đã đặt của từng ca khám.',
      7: 'Tra cứu giao dịch và đối chiếu thông tin thanh toán.',
      8: 'Lắng nghe phản hồi và đánh giá của bệnh nhân.',
      9: 'Tra cứu vai trò, trạng thái và hồ sơ liên kết của tài khoản.',
      10: 'Tra cứu hồ sơ sức khỏe theo phạm vi được cấp quyền.',
      11: 'Tra cứu kết quả cận lâm sàng theo phạm vi được cấp quyền.',
      12: 'Theo dõi nội dung thông báo và trạng thái đã đọc.',
      13: 'Tra cứu lịch sử tư vấn AI theo phạm vi được cấp quyền.',
    };
    return _AdminSectionBackdrop(
      padding: MediaQuery.sizeOf(context).width >= 1100 ? 30 : 16,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F7FF), Color(0xFFD1EDFF), Color(0xFFBFE6FC)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descriptions[_selected] ?? '',
              style: const TextStyle(
                fontSize: 13,
                height: 1.7,
                color: _ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _summaryValue(
                    dataset.error != null ? '—' : '${dataset.records.length}',
                    'Tổng bản ghi',
                  ),
                ),
                Container(width: 1, height: 40, color: const Color(0xFFBDDDF4)),
                Expanded(
                  child: _summaryValue(
                    dataset.error != null
                        ? '—'
                        : '${dataset.records.where((r) => r.isSample).length}',
                    'Bản ghi mẫu',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryValue(String value, String label) => Column(
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: _blue,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: _muted),
      ),
    ],
  );
  Widget _filterSurface(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FCFF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: child,
  );

  Widget _referenceFilter(
    String label,
    String collection,
    String selected,
    ValueChanged<String> onChanged, {
    double width = 220,
  }) => LayoutBuilder(
    builder: (context, box) {
      final dataset = _controller.dataset(collection);
      final records = dataset.records;
      return SizedBox(
        width: math.min(width, box.maxWidth.isFinite ? box.maxWidth : width),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$collection-$selected'),
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả')),
            if (selected != 'Tất cả' && !records.any((r) => r.id == selected))
              DropdownMenuItem(
                value: selected,
                child: Text(selected, overflow: TextOverflow.ellipsis),
              ),
            for (final record in records)
              DropdownMenuItem(
                value: record.id,
                child: Text(
                  readString(
                    record.data['fullName'] ?? record.data['name'],
                    fallback: record.id,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: dataset.loading || dataset.error != null
              ? null
              : (v) => onChanged(v ?? 'Tất cả'),
        ),
      );
    },
  );

  Widget _recordCard(AdminSection section, AdminRecord record, bool demo) =>
      Card(
        color: const Color(0xFFF5FBFF),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _detail(section, record, demo),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(section.icon, size: 20, color: _blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.id,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: _blue),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  demo
                      ? 'DEMO cục bộ'
                      : record.isSample
                      ? 'Mẫu trên Firebase'
                      : 'Firebase',
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: _line),
                const SizedBox(height: 8),
                for (final entry in section.columns.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            entry.value,
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: entry.key == 'status'
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: _badge(
                                    _format(entry.key, record.data[entry.key]),
                                  ),
                                )
                              : Text(
                                  _format(entry.key, record.data[entry.key]),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _doctorCards(List<AdminRecord> records, bool demo) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 850
          ? 3
          : box.maxWidth >= 550
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final record in records)
            SizedBox(
              width: width,
              child: Card(
                color: const Color(0xFFF5FBFF),
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: _line),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _detail(adminSections[2], record, demo),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Color(0xFFE4F4FF),
                              child: Text(
                                readString(record.data['fullName']).isEmpty
                                    ? 'BS'
                                    : readString(record.data['fullName'])
                                          .substring(0, 1)
                                          .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _blue,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: _badge(
                                record.data['acceptingBookings'] == false
                                    ? 'Ngừng nhận lịch mới'
                                    : _format('status', record.data['status']),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _format('fullName', record.data['fullName']),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _format('specialtyId', record.data['specialtyId']),
                          style: const TextStyle(fontSize: 12, color: _blue),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _format('phone', record.data['phone']),
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Phí khám: ${_format('consultationFee', record.data['consultationFee'])}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Divider(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        adminSections[2].icon,
                                        size: 17,
                                        color: _blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          record.id,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: _blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (demo || record.isSample) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      demo
                                          ? 'DEMO cục bộ'
                                          : 'Mẫu trên Firebase',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const Text(
                              'Xem hồ sơ →',
                              style: TextStyle(fontSize: 11, color: _blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _scheduleDays(List<AdminRecord> records, bool demo) {
    final sorted = [...records]
      ..sort((a, b) {
        final first = adminVietnamDate(a.data['workDate']);
        final second = adminVietnamDate(b.data['workDate']);
        final comparison = (first ?? DateTime.utc(1900)).compareTo(
          second ?? DateTime.utc(1900),
        );
        return comparison != 0
            ? comparison
            : readString(a.data['startTime'])
                  .compareTo(readString(b.data['startTime']));
      });
    final groups = <String, List<AdminRecord>>{};
    for (final record in sorted) {
      final date = adminVietnamDate(record.data['workDate']);
      final label = date == null ? 'Chưa có ngày làm việc' : _dateText(date);
      groups.putIfAbsent(label, () => []).add(record);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              group.key,
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
            ),
          ),
          for (final record in group.value)
            _recordCard(adminSections[5], record, demo),
        ],
      ],
    );
  }

  Widget _table(
    AdminSection section,
    List<AdminRecord> records, {
    required bool demo,
  }) => LayoutBuilder(
    builder: (context, box) => box.maxWidth < 620
        ? Column(
            children: [
              for (final record in records) _recordCard(section, record, demo),
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: box.maxWidth),
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFF0F8FE),
                ),
                columnSpacing: 24,
                horizontalMargin: 12,
                dataRowMinHeight: 62,
                dataRowMaxHeight: 76,
                showCheckboxColumn: false,
                columns: [
                  const DataColumn(label: Text('Mã / Nguồn')),
                  for (final label in section.columns.values)
                    DataColumn(
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const DataColumn(label: Text('')),
                ],
                rows: [
                  for (final record in records)
                    DataRow(
                      onSelectChanged: (_) => _detail(section, record, demo),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 145,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(section.icon, size: 17, color: _blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        record.id,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  demo
                                      ? 'DEMO cục bộ'
                                      : record.isSample
                                      ? 'Mẫu trên Firebase'
                                      : 'Firebase',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: demo || record.isSample
                                        ? const Color(0xFFAD6A10)
                                        : _blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (final field in section.columns.keys)
                          DataCell(
                            field == 'status'
                                ? _badge(_format(field, record.data[field]))
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 210,
                                    ),
                                    child: Text(
                                      _format(field, record.data[field]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                          ),
                        DataCell(
                          IconButton(
                            tooltip: 'Xem chi tiết',
                            onPressed: () => _detail(section, record, demo),
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: _blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
  );

  void _detail(
    AdminSection section,
    AdminRecord record,
    bool demo,
  ) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) => Theme(
      data: _adminTheme(dialogContext),
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 760,
          height: math.min(700, MediaQuery.sizeOf(dialogContext).height * .85),
          child: DefaultTabController(
            length: demo ? 2 : 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEAF8FF), Color(0xFFD8EFFF)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(section.icon, color: _blue, size: 23),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Chi tiết ${section.title.toLowerCase()}',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: _blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        record.id,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                      const SizedBox(height: 12),
                      _badge(
                        demo
                            ? 'DEMO cục bộ'
                            : record.isSample
                            ? 'Mẫu trên Firebase'
                            : 'Firebase',
                      ),
                    ],
                  ),
                ),
                TabBar(
                  dividerColor: _line,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    const Tab(text: 'Thông tin'),
                    if (!demo) const Tab(text: 'Liên quan'),
                    const Tab(text: 'Dữ liệu mở rộng'),
                  ],
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => TabBarView(
                      children: [
                        _detailFields(section, {
                          'id': record.id,
                          for (final field in section.columns.keys)
                            field: record.data[field],
                          for (final field in [
                            'reason',
                            'symptoms',
                            'note',
                            'createdAt',
                            'updatedAt',
                          ])
                            if (record.data.containsKey(field))
                              field: record.data[field],
                        }),
                        if (!demo) _relatedRecords(section, record),
                        _detailFields(section, record.data),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _actionMenu(section, record, demo, () {
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        }),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _detailFields(AdminSection section, Map<String, dynamic> fields) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in fields.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FBFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.columns[entry.key] ??
                          adminFieldLabels[entry.key] ??
                          entry.key,
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _format(entry.key, entry.value),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
  Widget _relatedRecords(AdminSection section, AdminRecord record) {
    final relation = switch (section.collection) {
      'BENH_NHAN' => ('patientId', [1, 7, 10, 11]),
      'BAC_SI' => ('doctorId', [1, 5]),
      'LICH_LAM_VIEC' => ('workScheduleId', [6, 1]),
      'CA_KHAM' => ('timeSlotId', [1]),
      'LICH_HEN' => ('appointmentId', [7]),
      'CHUYEN_KHOA' => ('specialtyId', [2]),
      'TAI_KHOAN' => ('userId', [2, 3]),
      _ => ('', <int>[]),
    };
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        if (relation.$2.isEmpty)
          const Text(
            'Chưa có liên kết dữ liệu cho mục này.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        for (final index in relation.$2)
          Builder(
            builder: (context) {
              final target = adminSections[index];
              final dataset = _controller.dataset(target.collection!);
              final related = dataset.records
                  .where(
                    (r) =>
                        readReferenceId(
                          r.data[section.collection == 'TAI_KHOAN' && index == 3
                              ? 'authUserId'
                              : relation.$1],
                        ) ==
                        record.id,
                  )
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(target.icon, color: _blue, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            target.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (dataset.loading)
                      const LinearProgressIndicator()
                    else if (dataset.error != null) ...[
                      _notice(dataset.error!, error: true),
                      TextButton(
                        onPressed: () => _controller.retry(target.collection!),
                        child: const Text('Thử lại'),
                      ),
                    ] else if (related.isEmpty)
                      const Text(
                        'Chưa có bản ghi liên quan.',
                        style: TextStyle(fontSize: 12, color: _muted),
                      )
                    else ...[
                      for (final item in related.take(20))
                        _recordCard(target, item, false),
                      if (related.length > 20)
                        Text(
                          'Đang hiển thị 20/${related.length} bản ghi. Tra cứu thêm tại ${target.title.toLowerCase()}.',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _settings() => _settingsPanel();

  Widget _panel(
    String title,
    String subtitle,
    Widget child, {
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080864CA),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(adminSections[_selected].icon, color: _blue, size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: _muted, height: 1.7),
        ),
        const SizedBox(height: 20),
        Material(type: MaterialType.transparency, child: child),
      ],
    ),
  );

  Widget _notice(String message, {bool error = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF2E6) : const Color(0xFFEDF4FF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 19,
          color: error ? const Color(0xFFAD6A10) : _blue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, height: 1.7),
          ),
        ),
      ],
    ),
  );

  Widget _badge(String label) {
    final color = switch (label) {
      'Chờ xác nhận' => const Color(0xFFA66B12),
      'Đã xác nhận' || 'Còn chỗ' => _blue,
      'Hoàn thành' ||
      'Đã thanh toán' ||
      'Thành công' ||
      'Hoạt động' => const Color(0xFF278779),
      'Đã hủy' ||
      'Ngưng hoạt động' ||
      'Không hoạt động' ||
      'Vắng mặt' => const Color(0xFF6B7A8D),
      'Thất bại' || 'Tạm khóa' => const Color(0xFFBC5365),
      _ =>
        label.contains('DEMO') ||
                label.contains('Chưa') ||
                label.contains('Mẫu')
            ? const Color(0xFFA66B12)
            : _blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  String _format(String field, Object? value) {
    if (value == null || value == '') return 'Chưa có dữ liệu';
    if (field.endsWith('Id')) return _controller.referenceName(field, value);
    if (value is bool) return value ? 'Có' : 'Không';
    if ([
      'status',
      'role',
      'processingStatus',
      'reviewStatus',
      'refundStatus',
    ].contains(field)) {
      return _statusText('$value');
    }
    if (field == 'amount' || field == 'consultationFee') {
      final amount = readDouble(value).toStringAsFixed(0);
      return '${amount.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} đ';
    }
    if (value is DateTime ||
        value is Timestamp ||
        [
          'appointmentDate',
          'workDate',
          'dateOfBirth',
          'createdAt',
          'updatedAt',
          'paidAt',
          'recordDate',
          'testDate',
          'timestamp',
          'bookedAt',
          'checkInTime',
        ].contains(field)) {
      final date = readDateTime(value)?.toUtc().add(const Duration(hours: 7));
      if (date != null) return _dateText(date);
    }
    if (value is Map) {
      return value.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    }
    if (value is List) {
      return value.isEmpty ? 'Chưa có dữ liệu' : value.join(', ');
    }
    return '$value';
  }

  bool _sameDate(Object? value, DateTime day) {
    final date = readDateTime(value)?.toUtc().add(const Duration(hours: 7));
    return date != null &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  String _dateText(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _statusText(String status) => status == 'INACTIVE' && _selected == 5
      ? 'Không hoạt động'
      : const {
              'PENDING': 'Chờ xác nhận',
              'CONFIRMED': 'Đã xác nhận',
              'COMPLETED': 'Hoàn thành',
              'CANCELLED': 'Đã hủy',
              'NO_SHOW': 'Vắng mặt',
              'ACTIVE': 'Hoạt động',
              'INACTIVE': 'Ngưng hoạt động',
              'AVAILABLE': 'Còn chỗ',
              'BOOKED': 'Đã đầy',
              'UNAVAILABLE': 'Tạm khóa',
              'PAID': 'Đã thanh toán',
              'SUCCESS': 'Thành công',
              'FAILED': 'Thất bại',
              'NEW': 'Mới tiếp nhận',
              'PROCESSING': 'Đang xử lý',
              'RESOLVED': 'Đã xử lý',
              'DRAFT': 'Bản nháp',
              'SENT': 'Đã gửi',
              'REQUESTED': 'Đã yêu cầu',
              'REVIEWED': 'Đã đối soát',
              'UNREVIEWED': 'Chưa đối soát',
              'NEEDS_CHECK': 'Cần kiểm tra',
              'CREATING': 'Đang cấp tài khoản',
              'AUTH_CREATED': 'Đang tạo hồ sơ',
              'READY': 'Đã cấp tài khoản',
              'NEEDS_RECOVERY': 'Cần khôi phục',
              'ARCHIVED': 'Đã lưu trữ',
              'patient': 'Bệnh nhân',
              'doctor': 'Bác sĩ',
              'admin': 'Quản trị viên',
            }[status] ??
            status;
}
