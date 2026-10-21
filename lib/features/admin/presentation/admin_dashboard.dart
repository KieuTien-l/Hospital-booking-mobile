part of 'admin_workspace.dart';

class _AdminDashboard extends StatelessWidget {
  const _AdminDashboard({
    required this.contentPadding,
    required this.controller,
    required this.userName,
    required this.period,
    required this.periodPreset,
    required this.onPeriodChanged,
    required this.onNavigate,
    required this.onDetail,
  });

  final AdminController controller;
  final double contentPadding;
  final String userName;
  final DateTimeRange? period;
  final String periodPreset;
  final void Function(String preset, DateTimeRange period) onPeriodChanged;
  final void Function(int index, {String? status, DateTimeRange? period})
  onNavigate;
  final void Function(int index, AdminRecord record) onDetail;

  DateTime get today => DateTime.now().toUtc().add(const Duration(hours: 7));
  DateTimeRange get range =>
      period ?? DateTimeRange(start: adminDay(today), end: adminDay(today));

  @override
  Widget build(BuildContext context) {
    final appointments = controller.dataset('LICH_HEN');
    final payments = controller.dataset('THANH_TOAN');
    final selected =
        appointments.records
            .where(
              (r) => adminInPeriod(
                r.data['appointmentDate'],
                range.start,
                range.end,
              ),
            )
            .toList()
          ..sort(
            (a, b) =>
                '${a.data['appointmentDate']} ${a.data['startTime']}'.compareTo(
                  '${b.data['appointmentDate']} ${b.data['startTime']}',
                ),
          );
    final pending = selected
        .where((r) => adminStatus(r.data['status']) == 'PENDING')
        .length;
    final completed = selected
        .where((r) => adminStatus(r.data['status']) == 'COMPLETED')
        .length;
    final paid = payments.records
        .where(
          (r) => {'PAID', 'SUCCESS'}.contains(adminStatus(r.data['status'])),
        )
        .toList();
    final missingPaymentDates = paid
        .where((r) => adminVietnamDate(r.data['paidAt']) == null)
        .length;
    final total = adminCollectedTotal(payments.records, range.start, range.end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: -contentPadding,
              bottom: -contentPadding,
              left: -contentPadding,
              right: -contentPadding,
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE8F7FF),
                    Color(0xFFD1EDFF),
                    Color(0xFFBFE6FC),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny_outlined,
                              color: _blue,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chào ${userName.isEmpty ? 'quản trị viên' : userName}!',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  color: _blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sẵn sàng cho ngày làm việc mới.',
                          style: TextStyle(
                            color: _muted,
                            height: 1.6,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => onNavigate(1, period: range),
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                              ),
                              label: const Text('Xem lịch hẹn'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () => onNavigate(5, period: range),
                              icon: const Icon(Icons.schedule, size: 18),
                              label: const Text('Lịch làm việc'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width > 1100)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.health_and_safety_outlined,
                          size: 85,
                          color: Color(0xFF70BCEB),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 23, color: _blue),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Thống kê',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _periodFilter(context),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 4
                : box.maxWidth >= 560
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _metric(
                  width,
                  'Lịch khám trong kỳ',
                  '${selected.length}',
                  Icons.calendar_month_outlined,
                  appointments,
                  () => onNavigate(1, period: range),
                  'Theo ngày khám',
                ),
                _metric(
                  width,
                  'Chờ xác nhận',
                  '$pending',
                  Icons.pending_actions_outlined,
                  appointments,
                  () => onNavigate(1, status: 'PENDING', period: range),
                  'Trong khoảng đang chọn',
                  color: const Color(0xFFB87A19),
                ),
                _metric(
                  width,
                  'Đã hoàn thành',
                  '$completed',
                  Icons.task_alt,
                  appointments,
                  () => onNavigate(1, status: 'COMPLETED', period: range),
                  'Trong khoảng đang chọn',
                  color: const Color(0xFF278779),
                ),
                _metric(
                  width,
                  'Tiền đã thu',
                  _money(total),
                  Icons.account_balance_wallet_outlined,
                  payments,
                  () => onNavigate(7, status: 'Đã thu', period: range),
                  'Theo ngày thanh toán',
                  color: const Color(0xFF7563AB),
                ),
              ],
            );
          },
        ),
        if (missingPaymentDates > 0 &&
            payments.error == null &&
            !payments.loading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$missingPaymentDates giao dịch thành công thiếu ngày thanh toán, chưa được cộng vào tiền đã thu.',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        const SizedBox(height: 20),
        _pair(
          context,
          _card(
            Icons.show_chart_rounded,
            'Nhịp đặt khám',
            'Lượt khám theo ngày · 7 ngày cuối trong khoảng đang chọn',
            _data(appointments, () => _chart(selected)),
          ),
          _card(
            Icons.pending_actions_outlined,
            'Cần theo dõi',
            'Chọn một mục để mở danh sách liên quan',
            Column(
              children: [
                _followUp(
                  'Lịch chờ xác nhận',
                  appointments,
                  appointments.records
                      .where((r) => adminStatus(r.data['status']) == 'PENDING')
                      .length,
                  () => onNavigate(1, status: 'PENDING'),
                ),
                _followUp(
                  'Lịch đã hủy trong kỳ',
                  appointments,
                  selected
                      .where(
                        (r) => adminStatus(r.data['status']) == 'CANCELLED',
                      )
                      .length,
                  () => onNavigate(1, status: 'CANCELLED', period: range),
                ),
                _followUp(
                  'Phản hồi đã nhận',
                  controller.dataset('PHAN_HOI'),
                  controller.dataset('PHAN_HOI').records.length,
                  () => onNavigate(8),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Lịch chờ xác nhận được tính trên toàn bộ dữ liệu. Phản hồi chưa có trạng thái xử lý được hiển thị theo tổng đã nhận.',
                    style: TextStyle(fontSize: 11, height: 1.6, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _pair(
          context,
          _card(
            Icons.event_note_outlined,
            'Lịch khám trong kỳ',
            'Tối đa 5 lịch đầu theo ngày và giờ khám',
            _data(
              appointments,
              () => selected.isEmpty
                  ? _empty('Chưa có lịch khám trong khoảng này.')
                  : Column(
                      children: [
                        for (final record in selected.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE6F4FF),
                              child: Text(
                                readString(
                                  record.data['startTime'],
                                  fallback: '—',
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _blue,
                                ),
                              ),
                            ),
                            title: Text(
                              controller.referenceName(
                                'patientId',
                                record.data['patientId'],
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${controller.referenceName('doctorId', record.data['doctorId'])}\n${_dayText(adminVietnamDate(record.data['appointmentDate'])!)} · ${record.id}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: _blue,
                            ),
                            onTap: () => onDetail(1, record),
                          ),
                      ],
                    ),
            ),
            action: TextButton(
              onPressed: () => onNavigate(1, period: range),
              child: const Text('Xem tất cả'),
            ),
          ),
          _card(
            Icons.medical_services_outlined,
            'Bác sĩ làm việc hôm nay',
            _dayText(today),
            _doctorsToday(),
            action: IconButton(
              tooltip: 'Xem lịch làm việc hôm nay',
              onPressed: () => onNavigate(
                5,
                period: DateTimeRange(
                  start: adminDay(today),
                  end: adminDay(today),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, color: _blue, size: 19),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _card(
          Icons.pie_chart_outline_rounded,
          'Phân bổ theo chuyên khoa',
          'Số lịch khám trong khoảng đang chọn',
          _data(appointments, () => _specialties(selected)),
        ),
        const SizedBox(height: 20),
        _card(
          Icons.grid_view_rounded,
          'Truy cập nhanh',
          'Các nhóm công việc thường dùng',
          _quickAccess(),
        ),
        const SizedBox(height: 16),
        ExpansionTile(
          leading: const Icon(Icons.storage_rounded, size: 23, color: _blue),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: const Color(0xEFFFFFFF),
          collapsedBackgroundColor: const Color(0xBFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Trạng thái dữ liệu',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Thống kê gồm bản ghi mẫu đã lưu; không cộng DEMO cục bộ.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
          children: [
            for (final section in adminSections.where(
              (s) => s.collection != null,
            ))
              ListTile(
                dense: true,
                title: Text(
                  section.title,
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  controller.dataset(section.collection!).error ??
                      (controller
                                  .dataset(section.collection!)
                                  .records
                                  .isEmpty &&
                              !controller.dataset(section.collection!).loading
                          ? 'Chưa có bản ghi'
                          : controller
                                .dataset(section.collection!)
                                .sourceLabel),
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _quickAccess() => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 760
          ? 4
          : box.maxWidth >= 220
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final index in [2, 3, 4, 5, 7, 8, 9, 12])
            SizedBox(
              width: width,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0864CA),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFD5E9FA)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF5FBFF), Color(0xFFE5F2FD)],
                      ),
                    ),
                    child: InkWell(
                      onTap: () => onNavigate(index),
                      hoverColor: const Color(0x140864CA),
                      focusColor: const Color(0x200864CA),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 76),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Center(
                            child: Text(
                              adminSections[index].title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF245D94),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _periodFilter(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.filter_alt_outlined, size: 19, color: _blue),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: periodPreset,
            borderRadius: BorderRadius.circular(16),
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12,
              color: _ink,
            ),
            icon: const Icon(Icons.expand_more, color: _blue, size: 20),
            items: const [
              DropdownMenuItem(value: 'today', child: Text('Hôm nay')),
              DropdownMenuItem(value: 'month', child: Text('Tháng này')),
              DropdownMenuItem(value: 'year', child: Text('Năm nay')),
              DropdownMenuItem(value: 'custom', child: Text('Tùy chọn')),
            ],
            onChanged: (value) => _changePeriod(context, value),
          ),
        ),
      ],
    ),
  );

  Future<void> _changePeriod(BuildContext context, String? preset) async {
    if (preset == null) return;
    final now = today;
    if (preset == 'custom') {
      final value = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: DateTimeRange(
          start: DateTime(range.start.year, range.start.month, range.start.day),
          end: DateTime(range.end.year, range.end.month, range.end.day),
        ),
      );
      if (value != null && context.mounted) onPeriodChanged(preset, value);
      return;
    }
    final selected = switch (preset) {
      'month' => DateTimeRange(
        start: DateTime.utc(now.year, now.month),
        end: DateTime.utc(now.year, now.month + 1, 0),
      ),
      'year' => DateTimeRange(
        start: DateTime.utc(now.year),
        end: DateTime.utc(now.year, 12, 31),
      ),
      _ => DateTimeRange(start: adminDay(now), end: adminDay(now)),
    };
    onPeriodChanged(preset, selected);
  }

  Widget _metric(
    double width,
    String title,
    String value,
    IconData icon,
    AdminDataset dataset,
    VoidCallback onTap,
    String caption, {
    Color color = _blue,
  }) => SizedBox(
    width: width,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  dataset.loading || dataset.error != null ? '—' : value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dataset.loading
                    ? 'Đang tải…'
                    : dataset.error != null
                    ? 'Chưa đọc được dữ liệu'
                    : caption,
                style: const TextStyle(fontSize: 10, color: _muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pair(BuildContext context, Widget left, Widget right) =>
      LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 1000
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: right),
                ],
              )
            : Column(children: [left, const SizedBox(height: 20), right]),
      );

  Widget _card(
    IconData icon,
    String title,
    String subtitle,
    Widget child, {
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080864CA),
          offset: Offset(0, 5),
          blurRadius: 18,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 23, color: _blue),
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
          style: const TextStyle(fontSize: 11, color: _muted, height: 1.6),
        ),
        const SizedBox(height: 18),
        Material(type: MaterialType.transparency, child: child),
      ],
    ),
  );

  Widget _data(AdminDataset dataset, Widget Function() content) =>
      dataset.loading
      ? const Padding(
          padding: EdgeInsets.all(24),
          child: LinearProgressIndicator(),
        )
      : dataset.error != null
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dataset.error!,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.6),
            ),
          ],
        )
      : content();

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    ),
  );

  Widget _followUp(
    String title,
    AdminDataset dataset,
    int count,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 12)),
    trailing: Text(
      dataset.loading || dataset.error != null ? '—' : '$count →',
      style: const TextStyle(fontWeight: FontWeight.w700, color: _blue),
    ),
    onTap: onTap,
  );

  Widget _chart(List<AdminRecord> selected) {
    final days = List.generate(
      7,
      (i) => adminDay(range.end).subtract(Duration(days: 6 - i)),
    ).where((d) => !d.isBefore(adminDay(range.start))).toList();
    final counts = days
        .map(
          (day) => selected
              .where((r) => adminSameDay(r.data['appointmentDate'], day))
              .length,
        )
        .toList();
    final maximum = counts.fold<int>(1, math.max);
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${counts[i]}',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4 + counts[i] / maximum * 118,
                      constraints: const BoxConstraints(maxWidth: 45),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF20B0EE), _blue],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${days[i].day}/${days[i].month}',
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _doctorsToday() {
    final schedules = controller.dataset('LICH_LAM_VIEC');
    return _data(schedules, () {
      final records =
          schedules.records
              .where(
                (r) =>
                    adminSameDay(r.data['workDate'], today) &&
                    adminStatus(r.data['status']) != 'CANCELLED' &&
                    adminStatus(r.data['status']) != 'INACTIVE',
              )
              .toList()
            ..sort(
              (a, b) =>
                  readString(a.data['startTime'])
                      .compareTo(readString(b.data['startTime'])),
            );
      if (records.isEmpty) {
        return _empty('Chưa có lịch làm việc hôm nay.');
      }
      final slots = controller.dataset('CA_KHAM');
      return Column(
        children: [
          for (final record in records.take(5))
            Builder(
              builder: (context) {
                final related = slots.records
                    .where(
                      (s) =>
                          readReferenceId(s.data['workScheduleId']) ==
                          record.id,
                    )
                    .toList();
                final completeCapacity =
                    related.isNotEmpty &&
                    related.every(
                      (s) =>
                          s.data['capacity'] != null &&
                          s.data['bookedCount'] != null,
                    );
                final booked = related.fold(
                  0,
                  (v, s) => v + readInt(s.data['bookedCount']),
                );
                final capacity = related.fold(
                  0,
                  (v, s) => v + readInt(s.data['capacity']),
                );
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    controller.referenceName(
                      'doctorId',
                      record.data['doctorId'],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${readString(record.data['startTime'], fallback: '—')} – ${readString(record.data['endTime'], fallback: '—')}\n${slots.loading || slots.error != null || !completeCapacity ? 'Chưa có số chỗ đã xác minh' : '$booked / $capacity chỗ đã đặt'}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  onTap: () => onDetail(5, record),
                );
              },
            ),
        ],
      );
    });
  }

  Widget _specialties(List<AdminRecord> selected) {
    if (selected.isEmpty) {
      return _empty('Chưa có lịch khám để thống kê.');
    }
    final counts = <String, int>{};
    for (final r in selected) {
      final id = readReferenceId(r.data['specialtyId']);
      final label = id.isEmpty
          ? 'Chưa xác định chuyên khoa'
          : controller.referenceName('specialtyId', id);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${entry.value} lượt',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: entry.value / selected.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: const Color(0xFFEAF5FD),
                  color: const Color(0xFF20B0EE),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _dayText(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _money(double amount) =>
      '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} đ';
}

class _AdminViewState {
  const _AdminViewState(
    this.query,
    this.status,
    this.date,
    this.page,
    this.doctor,
    this.specialty,
    this.period,
  );
  final String query;
  final String status;
  final DateTime? date;
  final int page;
  final String doctor;
  final String specialty;
  final DateTimeRange? period;
}
