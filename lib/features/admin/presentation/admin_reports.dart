part of 'admin_workspace.dart';

extension _AdminReports on _AdminWorkspaceState {
  Widget _settingsPanel() {
    final dataset = _controller.dataset('CAU_HINH');
    final data =
        dataset.records.where((r) => r.id == 'general').firstOrNull?.data ?? {};
    return _panel(
      'Cấu hình hệ thống',
      'Thông tin quản trị và mặc định tạo lịch của admin',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dataset.loading)
            const LinearProgressIndicator()
          else if (dataset.error != null) ...[
            _notice(dataset.error!, error: true),
            TextButton(
              onPressed: () => _controller.retry('CAU_HINH'),
              child: const Text('Thử lại'),
            ),
          ] else ...[
            _notice(
              'Thông tin hỗ trợ và giá trị mặc định dùng khi admin tạo lịch. Không tự đổi chính sách đặt/hủy lịch trong luồng patient đang hoạt động.',
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có cấu hình được lưu.'),
              ),
            for (final entry in const {
              'hospitalName': 'Tên cơ sở',
              'supportPhone': 'Điện thoại hỗ trợ',
              'supportEmail': 'Email hỗ trợ',
              'address': 'Địa chỉ',
              'defaultSlotDuration': 'Thời lượng ca mặc định (phút)',
              'defaultCapacity': 'Sức chứa mặc định',
            }.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FBFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      readString(data[entry.key], fallback: 'Chưa thiết lập'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      action: _commands == null || dataset.loading || dataset.error != null
          ? null
          : TextButton(
              onPressed: () => _editSettings(data),
              child: const Text('Chỉnh sửa'),
            ),
    );
  }

  Future<void> _editSettings(Map<String, dynamic> data) async {
    await _editor(
      title: 'Cấu hình quản trị',
      description: 'Lưu thông tin hỗ trợ và giá trị mặc định cho biểu mẫu tạo lịch. Mỗi lần thay đổi đều ghi nhật ký.',
      fields: [
        AdminEditField(
          'hospitalName',
          'Tên cơ sở',
          required: true,
          initial: readString(data['hospitalName']),
        ),
        AdminEditField(
          'supportPhone',
          'Điện thoại hỗ trợ',
          required: true,
          initial: readString(data['supportPhone']),
        ),
        AdminEditField(
          'supportEmail',
          'Email hỗ trợ',
          required: true,
          input: AdminInput.email,
          initial: readString(data['supportEmail']),
        ),
        AdminEditField(
          'address',
          'Địa chỉ',
          initial: readString(data['address']),
        ),
        AdminEditField(
          'defaultSlotDuration',
          'Thời lượng ca mặc định (phút)',
          required: true,
          input: AdminInput.integer,
          initial: readString(data['defaultSlotDuration'], fallback: '30'),
        ),
        AdminEditField(
          'defaultCapacity',
          'Sức chứa mặc định',
          required: true,
          input: AdminInput.integer,
          initial: readString(data['defaultCapacity'], fallback: '5'),
        ),
      ],
      operation: 'saveSettings',
      collection: 'CAU_HINH',
    );
  }

  Widget _reportsPanel() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final range =
        _reportPeriod ??
        DateTimeRange(
          start: DateTime.utc(now.year, now.month),
          end: DateTime.utc(now.year, now.month + 1, 0),
        );
    final dataset = _controller.dataset('LICH_HEN');
    final payments = _controller.dataset('THANH_TOAN');
    final records = dataset.records
        .where(
          (r) =>
              adminInPeriod(r.data['appointmentDate'], range.start, range.end),
        )
        .toList();
    final groups = <String, List<AdminRecord>>{};
    for (final record in records) {
      groups
          .putIfAbsent(
            _controller.referenceName('doctorId', record.data['doctorId']),
            () => [],
          )
          .add(record);
    }
    int count(List<AdminRecord> values, String status) =>
        values.where((r) => r.data['status'] == status).length;
    final csvRows = <List<String>>[
      [
        'Bác sĩ',
        'Tổng lịch',
        'Chờ xác nhận',
        'Đã xác nhận',
        'Hoàn thành',
        'Hủy',
        'Vắng mặt',
      ],
      for (final entry in groups.entries)
        [
          entry.key,
          '${entry.value.length}',
          for (final status in [
            'PENDING',
            'CONFIRMED',
            'COMPLETED',
            'CANCELLED',
            'NO_SHOW',
          ])
            '${count(entry.value, status)}',
        ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          'Báo cáo hoạt động',
          '${_dateText(range.start)} – ${_dateText(range.end)} · Theo ngày khám',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickReportPeriod,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: const Text('Chọn khoảng báo cáo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: dataset.loading || dataset.error != null
                        ? null
                        : () => _copyReport(csvRows),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Sao chép CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (dataset.loading)
                const LinearProgressIndicator()
              else if (dataset.error != null)
                _notice(dataset.error!, error: true)
              else ...[
                _notice(
                  '${records.length} lịch khám · ${count(records, 'COMPLETED')} hoàn thành · ${count(records, 'CANCELLED')} đã hủy. Thống kê gồm bản ghi mẫu đã lưu nếu có.',
                ),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Chưa có lịch khám trong kỳ.'),
                  ),
                for (final entry in groups.entries)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5FBFF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            Text('Tổng: ${entry.value.length}'),
                            Text(
                              'Hoàn thành: ${count(entry.value, 'COMPLETED')}',
                            ),
                            Text('Hủy: ${count(entry.value, 'CANCELLED')}'),
                            Text(
                              'Chờ xác nhận: ${count(entry.value, 'PENDING')}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _panel(
          'Thu tiền trong kỳ',
          'Theo ngày thanh toán, không suy diễn từ ngày tạo giao dịch',
          payments.loading
              ? const LinearProgressIndicator()
              : payments.error != null
              ? _notice(payments.error!, error: true)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _format(
                        'amount',
                        adminCollectedTotal(
                          payments.records,
                          range.start,
                          range.end,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chỉ cộng PAID/SUCCESS có paidAt và số tiền hợp lệ. Giao dịch thiếu ngày thanh toán không được tính.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _copyReport(List<List<String>> rows) async {
    String cell(String value) {
      final safe = RegExp(r'^[=+@\-\t\r]').hasMatch(value) ? "'$value" : value;
      return '"${safe.replaceAll('"', '""')}"';
    }

    await Clipboard.setData(
      ClipboardData(
        text: rows.map((row) => row.map(cell).join(',')).join('\r\n'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã sao chép CSV. Có thể dán vào Excel hoặc lưu thành tệp CSV.',
          ),
        ),
      );
    }
  }
}
