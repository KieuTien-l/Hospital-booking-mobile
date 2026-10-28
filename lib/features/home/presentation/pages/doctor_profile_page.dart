import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/presentation/widgets/doctor_detail_section.dart';
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

  String? _dateOfBirthLabel(DateTime? date) => date == null
      ? null
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      'Họ và tên',
                      value: name,
                      key: ValueKey('doctor-name-${user?.id}-$name'),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'Ngày sinh',
                      value: _dateOfBirthLabel(doctor?.dateOfBirth),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'Email',
                      value: _firstVerifiedValue(doctor?.email, user?.email),
                      key: ValueKey(
                        'doctor-email-${user?.id}-${doctor?.email}-${user?.email}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'Số điện thoại',
                      value: _firstVerifiedValue(doctor?.phone, user?.phone),
                      key: ValueKey(
                        'doctor-phone-${user?.id}-${doctor?.phone}-${user?.phone}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hồ sơ hiện ở chế độ chỉ đọc. Quyền chỉnh sửa và chức năng lưu đang chờ xác minh.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const FilledButton(
                      onPressed: null,
                      child: Text('Lưu thay đổi'),
                    ),
                  ],
                ),
              ),
              _section(
                'Thông tin chuyên môn',
                'Chuyên khoa, đào tạo, kinh nghiệm',
                Icons.medical_services_outlined,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('Chuyên khoa', value: doctor?.specialtyName),
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
