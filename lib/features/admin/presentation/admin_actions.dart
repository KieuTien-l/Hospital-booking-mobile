part of 'admin_workspace.dart';

const _creatable = {
  'LICH_HEN',
  'BAC_SI',
  'BENH_NHAN',
  'CHUYEN_KHOA',
  'LICH_LAM_VIEC',
  'CA_KHAM',
  'THONG_BAO',
};

extension _AdminActions on _AdminWorkspaceState {
  Map<String, String> _options(
    String collection, {
    bool Function(AdminRecord)? where,
  }) => {
    for (final record in _controller.dataset(collection).records)
      if (where == null || where(record))
        record.id: readString(
          record.data['fullName'] ??
              record.data['name'] ??
              record.data['email'],
          fallback: record.id,
        ),
  };

  Map<String, String> get _slotOptions {
    final result = <String, String>{};
    for (final slot in _controller.dataset('CA_KHAM').records) {
      if (slot.data['status'] != 'AVAILABLE' ||
          slot.data['capacity'] is! num ||
          slot.data['bookedCount'] is! num ||
          readInt(slot.data['capacity']) <= readInt(slot.data['bookedCount'])) {
        continue;
      }
      for (final schedule in _controller.dataset('LICH_LAM_VIEC').records) {
        if (schedule.id != readReferenceId(slot.data['workScheduleId']) ||
            schedule.data['status'] != 'ACTIVE') {
          continue;
        }
        final date = adminVietnamDate(schedule.data['workDate']);
        if (date == null) continue;
        result[slot.id] =
            '${_controller.referenceName('doctorId', slot.data['doctorId'])} · ${_dateText(date)} ${readString(slot.data['startTime'])} · ${readInt(slot.data['capacity']) - readInt(slot.data['bookedCount'])} chỗ';
      }
    }
    return result;
  }

  List<AdminEditField> _editFields(String collection, AdminRecord? record) {
    final data = record?.data ?? <String, dynamic>{};
    String value(String key, [String fallback = '']) =>
        readString(data[key], fallback: fallback);
    String dateValue(String key) {
      final d = adminVietnamDate(data[key]);
      return d == null
          ? ''
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    AdminEditField field(
      String key,
      String label, {
      AdminInput input = AdminInput.text,
      bool required = false,
      String? initial,
      Map<String, String> options = const {},
      bool pastDate = false,
    }) => AdminEditField(
      key,
      label,
      input: input,
      required: required,
      initial: initial ?? value(key),
      options: options,
      pastDate: pastDate,
    );
    final general =
        _controller
            .dataset('CAU_HINH')
            .records
            .where((r) => r.id == 'general')
            .firstOrNull
            ?.data ??
        {};
    switch (collection) {
      case 'BAC_SI':
        return [
          field('fullName', 'Họ và tên', required: true),
          if (record == null)
            field(
              'loginEmail',
              'Email đăng nhập (admin cấp)',
              input: AdminInput.email,
              required: true,
            ),
          field('email', 'Email liên hệ', input: AdminInput.email),
          field('phone', 'Điện thoại'),
          field(
            'dateOfBirth',
            'Ngày sinh',
            input: AdminInput.date,
            initial: dateValue('dateOfBirth'),
            pastDate: true,
          ),
          field(
            'gender',
            'Giới tính',
            input: AdminInput.choice,
            options: const {'Nam': 'Nam', 'Nữ': 'Nữ', 'Khác': 'Khác'},
          ),
          field('address', 'Địa chỉ'),
          field(
            'specialtyId',
            'Chuyên khoa',
            input: AdminInput.choice,
            required: true,
            options: _options(
              'CHUYEN_KHOA',
              where: (r) => r.data['status'] == 'ACTIVE',
            ),
          ),
          field('qualification', 'Bằng cấp / học vị'),
          field(
            'yearsOfExperience',
            'Số năm kinh nghiệm',
            input: AdminInput.integer,
            required: true,
            initial: value('yearsOfExperience', '0'),
          ),
          field(
            'consultationFee',
            'Phí khám (đồng)',
            input: AdminInput.number,
            required: true,
            initial: value('consultationFee', '0'),
          ),
          field('biography', 'Giới thiệu', input: AdminInput.multiline),
          field('avatarUrl', 'URL ảnh đại diện (HTTPS)'),
        ];
      case 'CHUYEN_KHOA':
        return [
          field('name', 'Tên chuyên khoa', required: true),
          field('description', 'Mô tả', input: AdminInput.multiline),
        ];
      case 'BENH_NHAN':
        return [
          if (record == null)
            field(
              'authUserId',
              'Tài khoản bệnh nhân liên kết',
              input: AdminInput.choice,
              required: true,
              options: _options(
                'TAI_KHOAN',
                where: (r) =>
                    r.data['role'] == 'patient' && r.data['isActive'] == true,
              ),
            ),
          field('fullName', 'Họ và tên', required: true),
          field('phone', 'Điện thoại'),
          field('email', 'Email liên hệ', input: AdminInput.email),
          field(
            'dateOfBirth',
            'Ngày sinh',
            input: AdminInput.date,
            initial: dateValue('dateOfBirth'),
            pastDate: true,
          ),
          field(
            'gender',
            'Giới tính',
            input: AdminInput.choice,
            options: const {'Nam': 'Nam', 'Nữ': 'Nữ', 'Khác': 'Khác'},
          ),
          field('address', 'Địa chỉ'),
          field('nationalId', 'Giấy tờ định danh'),
          field('insuranceNumber', 'Số bảo hiểm'),
        ];
      case 'LICH_LAM_VIEC':
        return [
          field(
            'doctorId',
            'Bác sĩ',
            required: true,
            input: AdminInput.choice,
            options: _options(
              'BAC_SI',
              where: (r) => r.data['status'] == 'ACTIVE',
            ),
          ),
          field(
            'workDate',
            'Ngày làm việc',
            required: true,
            input: AdminInput.date,
            initial: dateValue('workDate'),
          ),
          field(
            'startTime',
            'Giờ bắt đầu',
            required: true,
            input: AdminInput.time,
            initial: value('startTime', '08:00'),
          ),
          field(
            'endTime',
            'Giờ kết thúc',
            required: true,
            input: AdminInput.time,
            initial: value('endTime', '11:00'),
          ),
          field(
            'slotDuration',
            'Thời lượng mỗi ca (phút)',
            input: AdminInput.integer,
            required: true,
            initial: value(
              'slotDuration',
              '${general['defaultSlotDuration'] ?? 30}',
            ),
          ),
          field(
            'capacity',
            'Sức chứa mỗi ca',
            input: AdminInput.integer,
            required: true,
            initial: value('capacity', '${general['defaultCapacity'] ?? 5}'),
          ),
          if (record == null)
            field(
              'repeatWeeks',
              'Lặp cùng ngày trong tuần (1–8 tuần)',
              input: AdminInput.integer,
              required: true,
              initial: '1',
            ),
        ];
      case 'CA_KHAM':
        return [
          if (record == null)
            field(
              'workScheduleId',
              'Lịch làm việc',
              required: true,
              input: AdminInput.choice,
              options: {
                for (final r in _controller.dataset('LICH_LAM_VIEC').records)
                  if (r.data['status'] == 'ACTIVE')
                    r.id:
                        '${_controller.referenceName('doctorId', r.data['doctorId'])} · ${_format('workDate', r.data['workDate'])} ${readString(r.data['startTime'])}–${readString(r.data['endTime'])}',
              },
            ),
          field(
            'startTime',
            'Giờ bắt đầu',
            required: true,
            input: AdminInput.time,
            initial: value('startTime', '08:00'),
          ),
          field(
            'endTime',
            'Giờ kết thúc',
            required: true,
            input: AdminInput.time,
            initial: value('endTime', '08:30'),
          ),
          field(
            'capacity',
            'Sức chứa (không nhỏ hơn số đã đặt)',
            input: AdminInput.integer,
            required: true,
            initial: value('capacity', '5'),
          ),
        ];
      case 'LICH_HEN':
        return [
          field(
            'patientId',
            'Hồ sơ bệnh nhân',
            input: AdminInput.choice,
            required: true,
            options: _options(
              'BENH_NHAN',
              where: (r) =>
                  r.data['status'] != 'ARCHIVED' && r.data['isActive'] != false,
            ),
          ),
          field(
            'timeSlotId',
            'Ca khám còn chỗ',
            input: AdminInput.choice,
            required: true,
            options: _slotOptions,
          ),
          field(
            'peopleCount',
            'Số người',
            input: AdminInput.integer,
            required: true,
            initial: '1',
          ),
          field('reason', 'Lý do khám', input: AdminInput.multiline),
        ];
      case 'THONG_BAO':
        return [
          field(
            'patientId',
            'Người nhận (hồ sơ bệnh nhân)',
            input: AdminInput.choice,
            required: true,
            options: _options('BENH_NHAN'),
          ),
          field('title', 'Tiêu đề', required: true),
          field(
            'content',
            'Nội dung',
            required: true,
            input: AdminInput.multiline,
          ),
        ];
      default:
        return [];
    }
  }

  Future<Map<String, dynamic>?> _editor({
    required String title,
    required String description,
    required List<AdminEditField> fields,
    required String operation,
    required String collection,
    AdminRecord? record,
    String submitLabel = 'Lưu',
    Map<String, dynamic> fixedValues = const {},
    String? targetId,
  }) async {
    final commands = _commands;
    if (commands == null) return null;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => Theme(
        data: _adminTheme(dialogContext),
        child: AdminEditor(
          title: title,
          description: description,
          fields: fields,
          submitLabel: submitLabel,
          onSubmit: (values, reason, requestId) async {
            final result = await commands.execute({
              'requestId': requestId,
              'operation': operation,
              'collection': collection,
              if (targetId != null || record != null)
                'id': targetId ?? record!.id,
              if (record != null &&
                  targetId == null &&
                  readDateTime(record.data['updatedAt']) != null)
                'expectedUpdatedAt': readDateTime(record.data['updatedAt'])!
                    .millisecondsSinceEpoch,
              'values': {...values, ...fixedValues},
              'reason': reason,
            });
            if (operation == 'passwordSetup') {
              await commands.sendPasswordSetup(
                readString(result['loginEmail']),
              );
            }
            return result;
          },
        ),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            operation == 'passwordSetup'
                ? 'Đã gửi yêu cầu email thiết lập mật khẩu.'
                : readString(result['message'], fallback: 'Đã hoàn tất.'),
          ),
        ),
      );
    }
    return result;
  }

  Widget? _createButton(AdminSection section) {
    if (!_creatable.contains(section.collection) ||
        (_commands == null && section.collection != 'BAC_SI')) {
      return null;
    }
    final source = _controller.dataset(section.collection!);
    if (source.loading || source.error != null) return null;
    return FilledButton.icon(
      onPressed: () => _createRecord(section),
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        section.collection == 'BAC_SI'
            ? 'Thêm bác sĩ & tài khoản'
            : section.collection == 'THONG_BAO'
            ? 'Soạn thông báo'
            : 'Thêm ${section.title.toLowerCase()}',
      ),
    );
  }

  Future<void> _createRecord(AdminSection section) async {
    final collection = section.collection!;
    if (collection == 'BAC_SI') {
      await _createDoctorWithAccount();
      return;
    }
    final operation = switch (collection) {
      'LICH_HEN' => 'book',
      'LICH_LAM_VIEC' => 'createSchedule',
      'CA_KHAM' => 'saveSlot',
      'THONG_BAO' => 'notificationDraft',
      _ => 'create',
    };
    await _editor(
      title: collection == 'BAC_SI'
          ? 'Thêm bác sĩ và cấp tài khoản'
          : 'Thêm ${section.title.toLowerCase()}',
      description: collection == 'BAC_SI'
          ? 'Admin tạo tài khoản bác sĩ. Bác sĩ sẽ thiết lập mật khẩu qua email; phiên admin được giữ nguyên. Email liên hệ khác với email đăng nhập.'
          : collection == 'LICH_LAM_VIEC'
          ? 'Tự sinh ca khám. Không tạo lịch Chủ nhật; thứ bảy chỉ trước 12:00. Máy chủ kiểm tra trùng giờ trước khi lưu.'
          : 'Tạo bản ghi thật trên hệ thống. Máy chủ kiểm tra quyền, liên kết và lưu nhật ký; dữ liệu DEMO cục bộ không được sửa.',
      fields: _editFields(collection, null),
      operation: operation,
      collection: collection,
      submitLabel: collection == 'THONG_BAO' ? 'Lưu bản nháp' : 'Tạo',
    );
  }

  Future<void> _createDoctorWithAccount() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => Theme(
        data: _adminTheme(dialogContext),
        child: AdminEditor(
          title: 'Thêm bác sĩ và cấp tài khoản',
          description: 'Tài khoản mới luôn có vai trò Bác sĩ. App tạo đăng nhập bằng phiên phụ nên phiên admin hiện tại được giữ nguyên, sau đó tạo TAI_KHOAN và BAC_SI trên Firestore rồi gửi email đặt mật khẩu.',
          fields: _editFields('BAC_SI', null),
          submitLabel: 'Tạo',
          onSubmit: (values, _, _) async {
            final provisioned = await _doctorProvisioner.provision(values);
            return {
              'id': provisioned.doctorId,
              'loginEmail': provisioned.loginEmail,
              'passwordSetupSent': provisioned.passwordSetupSent,
              'message': provisioned.message,
            };
          },
        ),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readString(result['message']))));
    }
  }

  List<(String, String)> _recordActionItems(
    AdminSection section,
    AdminRecord record,
  ) {
    final c = section.collection, d = record.data;
    return [
      if ([
            'BAC_SI',
            'BENH_NHAN',
            'CHUYEN_KHOA',
            'LICH_LAM_VIEC',
            'CA_KHAM',
          ].contains(c) ||
          c == 'THONG_BAO' && d['status'] == 'DRAFT')
        ('edit', 'Chỉnh sửa thông tin'),
      if ([
        'BAC_SI',
        'BENH_NHAN',
        'CHUYEN_KHOA',
        'LICH_LAM_VIEC',
        'CA_KHAM',
      ].contains(c))
        (
          'availability',
          c == 'BAC_SI'
              ? d['acceptingBookings'] == false
                    ? 'Mở nhận lịch mới'
                    : 'Ngừng nhận lịch mới'
              : c == 'BENH_NHAN'
              ? d['status'] == 'ARCHIVED'
                    ? 'Khôi phục hồ sơ'
                    : 'Lưu trữ hồ sơ'
              : c == 'CA_KHAM'
              ? d['status'] == 'UNAVAILABLE'
                    ? 'Mở nhận đặt'
                    : 'Khóa nhận đặt'
              : d['status'] == 'INACTIVE'
              ? 'Bật hoạt động'
              : 'Ngừng hoạt động',
        ),
      if (['CHUYEN_KHOA', 'BAC_SI', 'LICH_LAM_VIEC', 'CA_KHAM'].contains(c) ||
          c == 'THONG_BAO' && d['status'] == 'DRAFT')
        ('delete', 'Xóa bản ghi chưa sử dụng'),
      if (c == 'LICH_LAM_VIEC') ('copy', 'Sao chép sang ngày khác'),
      if (c == 'LICH_HEN') ...[
        if (d['status'] == 'PENDING') ('confirm', 'Xác nhận lịch hẹn'),
        if (['PENDING', 'CONFIRMED'].contains(d['status'])) ...[
          ('reschedule', 'Đổi lịch khám'),
          ('cancel', 'Hủy lịch hẹn'),
        ],
        if (d['status'] == 'CONFIRMED') ('noShow', 'Đánh dấu vắng mặt'),
        ('note', 'Ghi chú nội bộ'),
      ],
      if (c == 'TAI_KHOAN') ('access', 'Quản lý quyền / khóa tài khoản'),
      if (c == 'TAI_KHOAN' && d['role'] == 'doctor' ||
          c == 'BAC_SI' && readString(d['userId']).isNotEmpty)
        ('password', 'Gửi email thiết lập mật khẩu'),
      if (c == 'PHAN_HOI') ('feedback', 'Phân công / xử lý phản hồi'),
      if (c == 'YEU_CAU_BAC_SI' && d['status'] == 'PENDING')
        ('reviewDoctorRequest', 'Duyệt / trả lời yêu cầu'),
      if (c == 'THONG_BAO' && d['status'] == 'DRAFT')
        ('send', 'Xem trước và gửi'),
      if (c == 'THANH_TOAN') ...[
        ('review', 'Ghi nhận đối soát'),
        if (['PAID', 'SUCCESS'].contains(d['status']) &&
            d['refundRequestId'] == null)
          ('refund', 'Yêu cầu hoàn tiền'),
      ],
    ];
  }

  Widget _actionMenu(
    AdminSection section,
    AdminRecord record,
    bool demo,
    VoidCallback onCompleted,
  ) {
    final items = _recordActionItems(section, record);
    if (demo || _commands == null || items.isEmpty) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Thao tác quản trị',
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(value: item.$1, child: Text(item.$2)),
      ],
      onSelected: (action) async {
        final result = await _dispatchAction(section, record, action);
        if (result != null && mounted) onCompleted();
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 18, color: _blue),
            SizedBox(width: 8),
            Text(
              'Thao tác quản trị',
              style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _dispatchAction(
    AdminSection section,
    AdminRecord record,
    String action,
  ) async {
    final collection = section.collection!, d = record.data;
    if (action == 'password') {
      final accountId = collection == 'BAC_SI'
          ? readReferenceId(d['userId'])
          : record.id;
      final account = _controller
          .dataset('TAI_KHOAN')
          .records
          .where((item) => item.id == accountId)
          .firstOrNull;
      final loginEmail = readString(account?.data['email']);
      if (loginEmail.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy email đăng nhập của bác sĩ.'),
            ),
          );
        }
        return null;
      }
      try {
        await _doctorProvisioner.sendPasswordSetup(loginEmail);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã gửi email thiết lập mật khẩu đến $loginEmail.'),
            ),
          );
        }
        return {
          'id': accountId,
          'collection': 'TAI_KHOAN',
          'loginEmail': loginEmail,
          'message': 'Đã gửi email thiết lập mật khẩu.',
        };
      } on AdminCommandException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return null;
      }
    }
    String
    title = 'Cập nhật ${section.title.toLowerCase()}',
    description =
        'Máy chủ kiểm tra quyền và trạng thái mới nhất trước khi lưu. Mọi thay đổi đều có nhật ký.',
    operation = action;
    List<AdminEditField> fields = [];
    Map<String, dynamic> fixed = {};
    AdminRecord? target = record;
    String? targetId;
    String targetCollection = collection;
    switch (action) {
      case 'reviewDoctorRequest':
        title = 'Xử lý yêu cầu bác sĩ';
        fields = [
          const AdminEditField(
            'status',
            'Kết quả xử lý',
            input: AdminInput.choice,
            required: true,
            options: {
              'APPROVED': 'Phê duyệt',
              'REJECTED': 'Từ chối',
              'RESOLVED': 'Đã xử lý',
            },
          ),
          const AdminEditField(
            'adminResponse',
            'Phản hồi bác sĩ',
            input: AdminInput.multiline,
            required: true,
          ),
        ];
      case 'edit':
        operation = switch (collection) {
          'LICH_LAM_VIEC' => 'editSchedule',
          'CA_KHAM' => 'saveSlot',
          'THONG_BAO' => 'notificationDraft',
          _ => 'save',
        };
        fields = _editFields(collection, record);
      case 'copy':
        operation = 'createSchedule';
        target = null;
        title = 'Sao chép lịch làm việc';
        description = 'Chọn ngày mới. Ca khám được sinh lại, không sao chép bệnh nhân hay lịch hẹn.';
        fields = _editFields(collection, record);
      case 'availability':
        operation = 'setAvailability';
        final enabled = collection == 'BAC_SI'
            ? d['acceptingBookings'] == false
            : collection == 'BENH_NHAN'
            ? d['status'] == 'ARCHIVED'
            : ['INACTIVE', 'UNAVAILABLE'].contains(d['status']);
        fixed = {'enabled': enabled};
        title = _recordActionItems(
          section,
          record,
        ).firstWhere((a) => a.$1 == action).$2;
        final affected = _controller
            .dataset('LICH_HEN')
            .records
            .where(
              (r) =>
                  ['PENDING', 'CONFIRMED'].contains(r.data['status']) &&
                  (collection == 'LICH_LAM_VIEC'
                      ? r.data['workScheduleId'] == record.id
                      : collection == 'BAC_SI'
                      ? r.data['doctorId'] == record.id
                      : collection == 'CA_KHAM'
                      ? r.data['timeSlotId'] == record.id
                      : false),
            )
            .length;
        description =
            'Giữ nguyên lịch sử. Hiện đọc được $affected lịch hẹn chưa kết thúc liên quan; sau khi ngừng nhận lịch, cần xử lý riêng các cuộc hẹn bị ảnh hưởng. Thao tác này không tự hủy lịch và không tự khóa tài khoản bác sĩ.';
      case 'delete':
        title = 'Xóa ${record.id}';
        description = 'Chỉ xóa bản ghi tạo nhầm chưa có dữ liệu liên quan. Máy chủ kiểm tra lại trước khi xóa và lưu bản khôi phục. Hồ sơ bác sĩ bị xóa sẽ khóa tài khoản liên kết.';
      case 'confirm':
      case 'cancel':
      case 'noShow':
        operation = 'appointmentStatus';
        fixed = {
          'status': action == 'confirm'
              ? 'CONFIRMED'
              : action == 'cancel'
              ? 'CANCELLED'
              : 'NO_SHOW',
        };
        title = action == 'confirm'
            ? 'Xác nhận lịch hẹn'
            : action == 'cancel'
            ? 'Hủy lịch hẹn'
            : 'Đánh dấu vắng mặt';
        description = action == 'cancel'
            ? 'Hủy lịch và trả lại đúng số chỗ đã giữ trong cùng giao dịch. Gửi thông báo trong ứng dụng. Thanh toán đã thu cần xử lý hoàn tiền riêng.'
            : 'Trạng thái được kiểm tra lại trên máy chủ. Không sửa trạng thái lịch đã kết thúc.';
      case 'reschedule':
        operation = 'reschedule';
        title = 'Đổi lịch khám';
        description = 'Chọn ca mới còn đủ chỗ. Giải phóng ca cũ và giữ ca mới trong một giao dịch, giữ lịch sử đổi và thông báo bệnh nhân.';
        fields = [
          AdminEditField(
            'timeSlotId',
            'Ca khám mới',
            input: AdminInput.choice,
            required: true,
            options: {..._slotOptions}
              ..remove(readReferenceId(d['timeSlotId'])),
          ),
        ];
      case 'note':
        operation = 'internalNote';
        title = 'Ghi chú nội bộ';
        fields = [
          AdminEditField(
            'internalNote',
            'Nội dung (chỉ admin xem)',
            input: AdminInput.multiline,
            initial: readString(
              _controller
                  .dataset('ADMIN_NOTES')
                  .records
                  .where((r) => r.id == record.id)
                  .firstOrNull
                  ?.data['internalNote'],
            ),
          ),
        ];
      case 'access':
        operation = 'accountAccess';
        title = 'Quản lý quyền tài khoản';
        description = 'Không tự khóa/đổi quyền tài khoản admin đang dùng. Tài khoản đã có hồ sơ liên kết không được đổi sang vai trò khác.';
        fields = [
          AdminEditField(
            'role',
            'Vai trò',
            input: AdminInput.choice,
            required: true,
            initial: readString(d['role']),
            options: const {
              'patient': 'Bệnh nhân',
              'doctor': 'Bác sĩ',
              'admin': 'Quản trị viên',
            },
          ),
          AdminEditField(
            'active',
            'Trạng thái',
            input: AdminInput.choice,
            required: true,
            initial: d['isActive'] == true ? 'true' : 'false',
            options: const {'true': 'Hoạt động', 'false': 'Khóa tài khoản'},
          ),
        ];
      case 'password':
        operation = 'passwordSetup';
        title = 'Gửi email thiết lập mật khẩu';
        targetCollection = 'TAI_KHOAN';
        targetId = collection == 'BAC_SI'
            ? readReferenceId(d['userId'])
            : record.id;
        target = null;
        description = 'Gửi hướng dẫn đến email đăng nhập đã được máy chủ xác minh. Admin không xem hoặc đặt mật khẩu cố định cho bác sĩ.';
      case 'feedback':
        operation = 'feedback';
        title = 'Xử lý phản hồi';
        fields = [
          AdminEditField(
            'processingStatus',
            'Trạng thái xử lý',
            input: AdminInput.choice,
            required: true,
            initial: readString(d['processingStatus'], fallback: 'NEW'),
            options: const {
              'NEW': 'Mới',
              'PROCESSING': 'Đang xử lý',
              'RESOLVED': 'Đã xử lý',
            },
          ),
          AdminEditField(
            'assigneeId',
            'Người phụ trách',
            input: AdminInput.choice,
            initial: readString(d['assigneeId']),
            options: _options(
              'TAI_KHOAN',
              where: (r) =>
                  r.data['role'] == 'admin' && r.data['isActive'] == true,
            ),
          ),
          AdminEditField(
            'response',
            'Trả lời bệnh nhân',
            input: AdminInput.multiline,
            initial: readString(d['response']),
          ),
        ];
      case 'send':
        operation = 'sendNotification';
        title = 'Xem trước và gửi thông báo';
        description =
            'Người nhận: ${_controller.referenceName('patientId', d['patientId'])}\n\n${readString(d['title'])}\n\n${readString(d['content'])}\n\nGửi trong ứng dụng; thông báo đã gửi không được sửa hoặc xóa.';
      case 'review':
        operation = 'paymentReview';
        title = 'Đối soát giao dịch';
        description = 'Chỉ ghi nhận kết quả kiểm tra nội bộ; không thay đổi số tiền hoặc kết quả thanh toán điện tử.';
        fields = [
          AdminEditField(
            'reviewStatus',
            'Kết quả đối soát',
            input: AdminInput.choice,
            required: true,
            initial: readString(d['reviewStatus'], fallback: 'UNREVIEWED'),
            options: const {
              'UNREVIEWED': 'Chưa đối soát',
              'REVIEWED': 'Đã đối soát',
              'NEEDS_CHECK': 'Cần kiểm tra',
            },
          ),
          AdminEditField(
            'reviewNote',
            'Ghi chú đối soát',
            input: AdminInput.multiline,
            initial: readString(d['reviewNote']),
          ),
        ];
      case 'refund':
        operation = 'paymentReview';
        title = 'Yêu cầu hoàn tiền';
        fixed = {'refundRequested': true};
        description =
            'Tạo yêu cầu xử lý hoàn ${_format('amount', d['amount'])}. Chưa thực hiện chuyển tiền hoặc xác nhận đã hoàn. Cổng thanh toán cần tích hợp riêng để hoàn tiền thực tế.';
    }
    if (action == 'access') {
      final commands = _commands;
      if (commands == null) return null;
      // The generic editor passes booleans as choices; normalize at the gateway boundary.
      return _accessEditor(record, title, description, fields);
    }
    return _editor(
      title: title,
      description: description,
      fields: fields,
      operation: operation,
      collection: targetCollection,
      record: target,
      targetId: targetId,
      fixedValues: fixed,
      submitLabel: action == 'send'
          ? 'Xác nhận gửi'
          : action == 'delete'
          ? 'Xóa'
          : 'Xác nhận',
    );
  }

  Future<Map<String, dynamic>?> _accessEditor(
    AdminRecord record,
    String title,
    String description,
    List<AdminEditField> fields,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (c) => Theme(
        data: _adminTheme(c),
        child: AdminEditor(
          title: title,
          description: description,
          fields: fields,
          onSubmit: (values, reason, requestId) => _commands!.execute({
            'requestId': requestId,
            'operation': 'accountAccess',
            'collection': 'TAI_KHOAN',
            'id': record.id,
            'reason': reason,
            'values': {
              'role': values['role'],
              'isActive': values['active'] == 'true',
            },
          }),
        ),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(readString(result['message']))));
    }
    return result;
  }
}
