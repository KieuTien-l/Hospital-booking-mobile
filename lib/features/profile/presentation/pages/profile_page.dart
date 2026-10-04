import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

/// Content of the patient Profile tab; navigation belongs to the home shell.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    this.fullName = 'Nguyễn Văn An',
    this.email = 'nguyenvanan@gmail.com',
    this.phone = '0901234567',
    required this.onOpen,
    required this.onLogout,
    this.isLoggingOut = false,
  });

  final String fullName;
  final String email;
  final String phone;
  final ValueChanged<String> onOpen;
  final VoidCallback onLogout;
  final bool isLoggingOut;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      key: const PageStorageKey('patient-profile'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cá nhân',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.person_rounded,
                size: 46,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fullName.trim().isEmpty ? 'Bệnh nhân' : fullName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              email,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (phone.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              phone,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 28),
          _section(context, 'Thông tin cá nhân', const [
            (Icons.person_outline_rounded, 'Thông tin bệnh nhân'),
            (Icons.folder_shared_outlined, 'Hồ sơ cá nhân'),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Tài khoản', const [
            (Icons.lock_outline_rounded, 'Đổi mật khẩu'),
            (Icons.settings_outlined, 'Cài đặt'),
            (Icons.description_outlined, 'Chính sách & điều khoản'),
          ]),
          const SizedBox(height: 24),
          _section(context, 'Hỗ trợ', const [
            (Icons.help_outline_rounded, 'Hướng dẫn sử dụng'),
            (Icons.support_agent_rounded, 'Liên hệ / Hỗ trợ'),
          ]),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: isLoggingOut ? null : onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(isLoggingOut ? 'Đang đăng xuất…' : 'Đăng xuất'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              backgroundColor: AppColors.error.withValues(alpha: .05),
              side: BorderSide(color: AppColors.error.withValues(alpha: .25)),
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(
    BuildContext context,
    String title,
    List<(IconData, String)> items,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.textOnPrimary.withValues(alpha: .04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72, endIndent: 16),
                InkWell(
                  onTap: () => onOpen(items[i].$2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            items[i].$1,
                            color: const Color(0xFF2583E3),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            items[i].$2,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}
