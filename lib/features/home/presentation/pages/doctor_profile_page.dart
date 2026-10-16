import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/presentation/widgets/doctor_detail_section.dart';

/// Read-only until Doctor profile editing rights and data have been verified.
class DoctorProfilePage extends StatelessWidget {
  const DoctorProfilePage({
    super.key,
    this.doctor,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });
  final Doctor? doctor;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  void _previewAvatar(BuildContext context) => showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (context) => AlertDialog(
      title: const Text('Ảnh đại diện'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(48),
          const SizedBox(height: 16),
          Text(
            doctor?.avatarUrl?.isNotEmpty == true
                ? 'Ảnh đại diện bác sĩ.'
                : 'Đang sử dụng ảnh đại diện mặc định.',
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

  Widget _avatar(double radius) {
    final url = doctor?.avatarUrl;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: Icon(
        Icons.person_outline_rounded,
        size: radius,
        color: AppColors.textOnPrimary,
      ),
    );
    if (url == null || Uri.tryParse(url)?.scheme != 'https') return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }

  Widget _section(String title, String subtitle, IconData icon, Widget child) =>
      DoctorDetailSection(
        title: title,
        subtitle: subtitle,
        icon: icon,
        titleColor: AppColors.textPrimary,
        child: child,
      );

  Widget _field(String label, {String? value, Key? key}) => KeyedSubtree(
    // Keep a field's horizontal scroll offset separate from ExpansionTile's
    // saved boolean state when refreshed data replaces a keyed field.
    key: PageStorageKey('doctor-field-$label'),
    child: TextFormField(
      key: key,
      initialValue: value?.trim() ?? '',
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Chưa có dữ liệu được xác minh',
      ),
    ),
  );

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
              if (isLoading) const LinearProgressIndicator(),
              if (error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Không thể tải hồ sơ bác sĩ. $error',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              Center(child: _avatar(42)),
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
                      key: ValueKey(
                        'doctor-name-${user?.id}-$name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field('Ngày sinh'),
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
                    _field(
                      'Chuyên khoa',
                      value: doctor?.specialtyName ?? doctor?.specialtyId,
                      key: ValueKey(
                        'specialty-${doctor?.specialtyName}-${doctor?.specialtyId}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'Học vị',
                      value: doctor?.qualification,
                      key: ValueKey('qualification-${doctor?.qualification}'),
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'Kinh nghiệm',
                      value: doctor == null
                          ? null
                          : '${doctor!.yearsOfExperience} năm',
                      key: ValueKey('experience-${doctor?.yearsOfExperience}'),
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
                    Center(child: _avatar(36)),
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
                    _field(
                      'Email đăng nhập',
                      value: user?.email,
                      key: ValueKey('login-email-${user?.id}-${user?.email}'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Các chức năng bảo mật bổ sung chưa được kết nối.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
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
