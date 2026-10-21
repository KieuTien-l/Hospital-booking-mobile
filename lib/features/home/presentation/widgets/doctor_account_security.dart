import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Password ownership belongs to the doctor; personal/profile data belongs to admin.
class DoctorAccountSecurity extends StatelessWidget {
  const DoctorAccountSecurity({super.key});

  Future<void> _change(BuildContext context, bool reset) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user?.email == null) return;
    final current = TextEditingController(),
        next = TextEditingController(),
        confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    bool busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(reset ? 'Khôi phục mật khẩu' : 'Đổi mật khẩu'),
            content: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reset)
                      Text('Gửi hướng dẫn đến ${user!.email}?')
                    else ...[
                      TextFormField(
                        controller: current,
                        obscureText: true,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                        ),
                        validator: (v) => v?.isNotEmpty == true
                            ? null
                            : 'Nhập mật khẩu hiện tại.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: next,
                        obscureText: true,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu mới',
                        ),
                        validator: (v) => v != null && v.length >= 8
                            ? null
                            : 'Tối thiểu 8 ký tự.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirm,
                        obscureText: true,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',
                        ),
                        validator: (v) =>
                            v == next.text ? null : 'Mật khẩu chưa khớp.',
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!reset && !form.currentState!.validate()) return;
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (reset) {
                            await auth.sendPasswordResetEmail(
                              email: user!.email!,
                            );
                          } else {
                            await user!.reauthenticateWithCredential(
                              EmailAuthProvider.credential(
                                email: user.email!,
                                password: current.text,
                              ),
                            );
                            await user.updatePassword(next.text);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  reset
                                      ? 'Đã gửi yêu cầu email khôi phục mật khẩu.'
                                      : 'Đã đổi mật khẩu.',
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            update(() {
                              busy = false;
                              error = 'Không thể hoàn tất. Kiểm tra mật khẩu hiện tại, kết nối và thử lại.';
                            });
                          }
                        }
                      },
                child: Text(
                  busy
                      ? 'Đang xử lý…'
                      : reset
                      ? 'Gửi email'
                      : 'Đổi mật khẩu',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton(
        onPressed: () => _change(context, false),
        child: const Text('Đổi mật khẩu'),
      ),
      TextButton(
        onPressed: () => _change(context, true),
        child: const Text('Khôi phục mật khẩu'),
      ),
    ],
  );
}
