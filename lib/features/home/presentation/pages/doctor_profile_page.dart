import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/presentation/widgets/doctor_detail_section.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../widgets/doctor_account_security.dart';

/// Read-only until Doctor profile editing rights and data have been verified.
class DoctorProfilePage extends StatelessWidget {
  const DoctorProfilePage({
    super.key,
    this.doctor,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  /// Optional verified profile supplied by the doctor Workspace Worker.
  final Doctor? doctor;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  void _previewAvatar(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ảnh đại diện'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.person_outline_rounded,
              size: 54,
              color: AppColors.textOnPrimary,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Đang sử dụng ảnh đại diện mặc định.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  Widget _section(String title, String subtitle, IconData icon, Widget child) =>
      DoctorDetailSection(
        title: title,
        subtitle: subtitle,
        icon: icon,
        titleColor: AppColors.textPrimary,
        child: child,
      );

  Widget _field(String label, {String? value, Key? key}) =>
      _ReadOnlyProfileField(key: key, label: label, value: value);

  Widget _professionalSection(String title, {Widget? child}) =>
      DoctorDetailSection(
        title: title,
        titleColor: AppColors.textPrimary,
        child:
            child ??
            const Text(
              'Chưa có dữ liệu được xác minh.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
      );

  String? _firstVerifiedValue(String? primary, String? fallback) {
    final normalizedPrimary = primary?.trim() ?? '';
    return normalizedPrimary.isEmpty ? fallback : normalizedPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final doctor =
        this.doctor ??
        context.watch<DoctorWorkspaceController?>()?.data?.doctor;
    final user = auth.currentUser;
    final name = _firstVerifiedValue(doctor?.fullName, user?.fullName) ?? '';
    return SingleChildScrollView(
      key: const PageStorageKey('doctor-profile'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 46,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Hồ sơ bác sĩ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Thông tin tài khoản và chuyên môn',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (isLoading) const LinearProgressIndicator(),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: AppColors.error)),
                if (onRetry != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              _section(
                'Thông tin cá nhân',
                'Họ tên, ngày sinh, liên hệ',
                Icons.person_outline_rounded,
                _PersonalProfileEditor(
                  doctor: doctor,
                  fullName: name,
                  email: _firstVerifiedValue(doctor?.email, user?.email) ?? '',
                  phone: _firstVerifiedValue(doctor?.phone, user?.phone) ?? '',
                  workspace: context.watch<DoctorWorkspaceController?>(),
                ),
              ),
              _section(
                'Thông tin chuyên môn',
                'Chuyên khoa, đào tạo, kinh nghiệm',
                Icons.medical_services_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      'Chuyên khoa',
                      value: _firstVerifiedValue(
                        doctor?.specialtyName,
                        'Chưa cập nhật',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field('Học vị', value: doctor?.qualification),
                    const SizedBox(height: 16),
                    _field(
                      'Kinh nghiệm',
                      value: doctor == null
                          ? null
                          : '${doctor.yearsOfExperience} năm',
                    ),
                    const SizedBox(height: 20),
                    // Same section names as the Patient DoctorDetailPage. No demo data.
                    _professionalSection('Lịch khám bệnh'),
                    _professionalSection('Quá trình đào tạo'),
                    _professionalSection(
                      'Quá trình công tác',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kinh nghiệm khám, chữa bệnh',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có dữ liệu được xác minh.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Kinh nghiệm giảng dạy',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có dữ liệu được xác minh.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _professionalSection('Hiệp hội chuyên môn'),
                    _professionalSection('Công trình nghiên cứu'),
                    const SizedBox(height: 4),
                    const Text(
                      'Thông tin chuyên môn chỉ đọc và cần Admin xác thực.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _section(
                'Ảnh đại diện',
                'Xem và cập nhật ảnh hồ sơ',
                Icons.camera_alt_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          Icons.person_outline_rounded,
                          size: 40,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _previewAvatar(context),
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Xem ảnh'),
                        ),
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Chọn ảnh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chọn ảnh chưa khả dụng. Nguồn ảnh và quyền cập nhật đang chờ xác minh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _section(
                'Tài khoản',
                'Thông tin đăng nhập và bảo mật',
                Icons.verified_user_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('Email đăng nhập', value: user?.email),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn có thể đổi mật khẩu trực tiếp hoặc gửi email khôi phục.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const DoctorAccountSecurity(),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: auth.isLoading ? null : () => auth.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(
                        auth.isLoading ? 'Đang đăng xuất…' : 'Đăng xuất',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
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
}

class _PersonalProfileEditor extends StatefulWidget {
  const _PersonalProfileEditor({
    required this.doctor,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.workspace,
  });
  final Doctor? doctor;
  final String fullName, email, phone;
  final DoctorWorkspaceController? workspace;

  @override
  State<_PersonalProfileEditor> createState() => _PersonalProfileEditorState();
}

class _PersonalProfileEditorState extends State<_PersonalProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _birthDate;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  DateTime? _dateOfBirth;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.fullName);
    _birthDate = TextEditingController(
      text: _dateText(widget.doctor?.dateOfBirth),
    );
    _email = TextEditingController(text: widget.email);
    _phone = TextEditingController(text: widget.phone);
    _dateOfBirth = widget.doctor?.dateOfBirth;
  }

  @override
  void dispose() {
    _name.dispose();
    _birthDate.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _dateText(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _dateOfBirth == null) {
      if (_dateOfBirth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ngày sinh.')),
        );
      }
      return;
    }
    final workspace = widget.workspace;
    if (workspace == null) return;
    setState(() => _saving = true);
    try {
      await workspace.repository.updatePersonalProfile(
        userId: workspace.userId,
        draft: DoctorPersonalProfileDraft(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          dateOfBirth: _dateOfBirth!,
        ),
      );
      await workspace.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thông tin cá nhân.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.workspace != null && !_saving;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            enabled: enabled,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nhập họ và tên.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            readOnly: true,
            enabled: enabled,
            controller: _birthDate,
            decoration: const InputDecoration(labelText: 'Ngày sinh'),
            onTap: !enabled
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateOfBirth ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _dateOfBirth = date;
                        _birthDate.text = _dateText(date);
                      });
                    }
                  },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email liên hệ'),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())
                ? 'Email không hợp lệ.'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
            validator: (value) =>
                value == null || !RegExp(r'^0\d{9,10}$').hasMatch(value.trim())
                ? 'Số điện thoại không hợp lệ.'
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: enabled ? _save : null,
            child: Text(_saving ? 'Đang lưu…' : 'Lưu thay đổi'),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyProfileField extends StatefulWidget {
  const _ReadOnlyProfileField({super.key, required this.label, this.value});

  final String label;
  final String? value;

  @override
  State<_ReadOnlyProfileField> createState() => _ReadOnlyProfileFieldState();
}

class _ReadOnlyProfileFieldState extends State<_ReadOnlyProfileField> {
  late final TextEditingController _controller;

  String get _value => widget.value?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _value);
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyProfileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != _value) {
      _controller.value = TextEditingValue(
        text: _value,
        selection: TextSelection.collapsed(offset: _value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    readOnly: true,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: 'Chưa có dữ liệu được xác minh',
    ),
  );
}
