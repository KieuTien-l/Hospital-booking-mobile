import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/demo_doctor_workspace_repository.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../widgets/doctor_dashboard_stat_card.dart';
import '../widgets/doctor_today_appointments_section.dart';
import '../widgets/patient_home_background.dart';
import 'doctor_reports_page.dart';
import 'managed_doctor_profile_page.dart';

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key, this.showDemoData = true});

  /// Temporary preview; set to false to restore the unconnected-data UI.
  final bool showDemoData;

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage>
    with WidgetsBindingObserver {
  DoctorWorkspaceController? _workspace;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _workspace?.resume();
    } else {
      _workspace?.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account =
        context.watch<AuthController>().currentUser?.id ?? 'preview';
    if (_accountId == account) return;
    _workspace?.removeListener(_changed);
    _workspace?.dispose();
    _accountId = account;
    final provided = context.read<DoctorWorkspaceRepository?>();
    final repository =
        provided ??
        (widget.showDemoData ? const DemoDoctorWorkspaceRepository() : null);
    _workspace =
        repository == null || (!widget.showDemoData && repository.isDemo)
        ? null
        : DoctorWorkspaceController(repository: repository, userId: account);
    _workspace?.load(_selectedDate);
    _workspace?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workspace?.removeListener(_changed);
    _workspace?.dispose();
    super.dispose();
  }

  int _tab = 0;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  DateTime _stripStart = DateUtils.dateOnly(DateTime.now())
      .subtract(const Duration(days: 2));

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _selectDate(DateTime date, {bool resetStrip = false}) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      if (resetStrip) {
        _stripStart = _selectedDate.subtract(const Duration(days: 2));
      }
    });
    _workspace?.load(_selectedDate);
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Chọn ngày xem lịch',
    );
    if (date != null && mounted) _selectDate(date, resetStrip: true);
  }

  Widget _home(BuildContext context, AuthController auth) {
    final workspace = _workspace;
    final data = workspace?.data;
    final totals = data?.totals ?? const DoctorBookingTotals();
    final name = auth.currentUser?.fullName.trim() ?? '';
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const PageStorageKey('doctor-home'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty
                              ? 'Xin chào, Bác sĩ!'
                              : 'Xin chào, Bác sĩ $name!',
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tổng quan công việc và lịch khám',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textOnPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: .65),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface),
                    ),
                    child: const CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textOnPrimary,
                        size: 29,
                        semanticLabel: 'Ảnh đại diện mặc định',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 24,
                    color: AppColors.textOnPrimary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lịch làm việc',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surface),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textOnPrimary.withValues(alpha: .04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final dateButton = OutlinedButton.icon(
                          key: const ValueKey('doctor-date-picker'),
                          onPressed: _chooseDate,
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(_dateLabel(_selectedDate)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: AppColors.border.withValues(alpha: .45),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        final heading = Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.textOnPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ngày được chọn',
                                style: textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                        if (MediaQuery.textScalerOf(context).scale(14) > 20) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: dateButton,
                              ),
                              const SizedBox(height: 8),
                              heading,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 8),
                            dateButton,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Chọn ngày để xem các ca khám được phân công.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              _selectDate(DateTime.now(), resetStrip: true),
                          child: const Text('Hôm nay'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scaled =
                            MediaQuery.textScalerOf(context).scale(14) > 20;
                        final width = ((constraints.maxWidth - 32) / 5).clamp(
                          scaled ? 96.0 : 48.0,
                          120.0,
                        );
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < 5; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                _dateTile(
                                  context,
                                  _stripStart.add(Duration(days: i)),
                                  width,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (workspace != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: workspace.isLoading ? null : workspace.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Làm mới'),
                  ),
                ),
              if (workspace?.isLoading == true && data != null)
                const LinearProgressIndicator(),
              if (workspace?.hasError == true)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          workspace!.errorMessage ??
                              'Không thể tải dữ liệu bác sĩ.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: workspace.refresh,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(14) > 20
                      ? 1
                      : totals.pending > 0
                      ? 2
                      : 3;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final stat in [
                        (
                          'Đã đặt',
                          Icons.event_available_outlined,
                          totals.booked,
                        ),
                        ('Đã khám', Icons.done_all_rounded, totals.completed),
                        ('Chờ khám', Icons.schedule_rounded, totals.waiting),
                        if (totals.pending > 0)
                          (
                            'Chờ xác nhận',
                            Icons.pending_actions,
                            totals.pending,
                          ),
                      ])
                        SizedBox(
                          width: width,
                          child: DoctorDashboardStatCard(
                            label: stat.$1,
                            icon: stat.$2,
                            value: data != null ? stat.$3 : null,
                            isLoading:
                                workspace?.isLoading == true && data == null,
                            hasError:
                                workspace?.hasError == true && data == null,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              DoctorTodayAppointmentsSection(
                selectedDate: _selectedDate,
                state: data != null
                    ? DoctorAppointmentsDisplayState.data
                    : workspace?.isLoading == true
                    ? DoctorAppointmentsDisplayState.loading
                    : workspace?.hasError == true
                    ? DoctorAppointmentsDisplayState.error
                    : DoctorAppointmentsDisplayState.empty,
                schedules: data?.schedules ?? const [],
                timeSlots: data?.slots ?? const [],
                bookings: data?.bookings,
                isDemo: workspace?.repository.isDemo ?? false,
                workspace: workspace,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.textOnPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trạng thái dữ liệu',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            workspace?.repository.isDemo == true
                                ? 'Đang hiển thị dữ liệu mẫu theo ngày đang chọn. Thứ bảy chỉ có buổi sáng, Chủ nhật không có ca khám. Lịch và số liệu không phải dữ liệu thực tế và không được lưu lên hệ thống.'
                                : workspace == null
                                ? 'Lịch và thống kê chưa được kết nối. Các chỉ số hiển thị “—” khi chưa có dữ liệu được xác minh.'
                                : 'Dữ liệu theo tài khoản bác sĩ đăng nhập. Tự làm mới mỗi 30 giây; nhấn Làm mới để cập nhật ngay.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
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
  }

  Widget _dateTile(BuildContext context, DateTime date, double width) {
    final selected = DateUtils.isSameDay(date, _selectedDate);
    return Semantics(
      selected: selected,
      child: SizedBox(
        width: width,
        child: Material(
          color: selected ? AppColors.textOnPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _selectDate(date),
            borderRadius: BorderRadius.circular(14),
            child: Tooltip(
              message: 'Chọn ngày ${_dateLabel(date)}',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.textOnPrimary
                        : AppColors.border.withValues(alpha: .4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      date.weekday == DateTime.sunday
                          ? 'CN'
                          : 'T${date.weekday + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? AppColors.surface
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${date.day}/${date.month}',
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 18,
                              color: selected
                                  ? AppColors.surface
                                  : AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.textOnPrimary),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
          ),
        ),
      ),
      child: Builder(
        builder: (context) => PatientHomeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _tab == 0
                ? null
                : AppBar(
                    backgroundColor: Colors.transparent,
                    leading: BackButton(
                      color: AppColors.textPrimary,
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _tab = 0);
                      },
                    ),
                    title: Text(
                      const [
                        'Tổng quan bác sĩ',
                        'Báo cáo sự cố',
                        'Cá nhân',
                      ][_tab],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'BeVietnamPro',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                // Android can publish a zero-sized viewport before its first frame.
                if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                  return const SizedBox.shrink();
                }
                return ColoredBox(
                  color: Colors.transparent,
                  child: SafeArea(
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        _home(context, auth),
                        DoctorReportsPage(
                          key: ValueKey('reports-$_accountId'),
                          selectedDate: _selectedDate,
                          workspace: _workspace,
                        ),
                        ManagedDoctorProfilePage(
                          key: ValueKey('profile-$_accountId'),
                          doctor: _workspace?.repository.isDemo == false
                              ? _workspace?.data?.doctor
                              : null,
                          isLoading: _workspace?.isLoading == true,
                          error: _workspace?.errorMessage,
                          onRetry: _workspace?.refresh,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border.withValues(alpha: .25),
                  ),
                ),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 12,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: states.contains(WidgetState.selected)
                          ? AppColors.textOnPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (index) {
                    FocusScope.of(context).unfocus();
                    setState(() => _tab = index);
                  },
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.primaryLight,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(
                        Icons.home_rounded,
                        color: AppColors.textOnPrimary,
                      ),
                      label: 'Trang chủ',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.report_outlined),
                      selectedIcon: Icon(
                        Icons.report_rounded,
                        color: AppColors.textOnPrimary,
                      ),
                      label: 'Báo cáo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(
                        Icons.person,
                        color: AppColors.textOnPrimary,
                      ),
                      label: 'Cá nhân',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
