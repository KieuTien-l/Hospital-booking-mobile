import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../validators/auth_validators.dart';
import 'login_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _blue = Color(0xFF0060EF);
  static const _navy = Color(0xFF143D70);
  final _formKey = GlobalKey<FormState>();
  void _backToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  Widget _recoveryFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Email'),
        TextFormField(
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          decoration: _decoration(
            'Nhập email đã đăng ký...',
            Icons.email_outlined,
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: AuthValidators.email,
        ),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _showMessage(
      'Chức năng gửi liên kết đặt lại mật khẩu chưa được kết nối Firebase.',
    );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        color: Color(0xFF98ABC3),
        fontSize: 15,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: Icon(icon, color: _blue, size: 23),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8E3F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD8E3F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF384C5D),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'BeVietnamPro'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'BeVietnamPro',
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFDFF),
            gradient: RadialGradient(
              center: Alignment.topRight,
              radius: 1.25,
              colors: [Color(0xFFACD1FA), Color(0xFFFAFDFF)],
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomLeft,
                radius: 1.05,
                colors: [Color(0xFFC7E3FF), Color(0x00FAFDFF)],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: constraints.maxHeight > 700 ? 20 : 0,
                              ),
                              Center(
                                child: ClipRect(
                                  child: Align(
                                    widthFactor: 0.54,
                                    heightFactor: 0.54,
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 170,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: ClipRect(
                                  child: Align(
                                    widthFactor: 0.84,
                                    heightFactor: 0.56,
                                    child: Image.asset(
                                      'assets/images/name_logo.png',
                                      width: 156,
                                      semanticLabel: 'HealWay',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Text(
                                'Quên mật khẩu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nhập email đã đăng ký để nhận liên kết đặt lại mật khẩu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 16,
                                  color: Color(0xFF7D93AE),
                                ),
                              ),
                              const SizedBox(height: 38),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14143D70),
                                      blurRadius: 24,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: AutofillGroup(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _recoveryFields(),
                                        const SizedBox(height: 24),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF258CE8),
                                                Color(0xFF0055E4),
                                              ],
                                            ),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              minimumSize:
                                                  const Size.fromHeight(54),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: Text(
                                              'Gửi liên kết đặt lại',
                                              style: TextStyle(
                                                fontFamily: 'BeVietnamPro',
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              const Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Color(0xFFD6E1EE)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'hoặc',
                                      style: TextStyle(
                                        fontFamily: 'BeVietnamPro',
                                        fontSize: 14,
                                        color: Color(0xFF7D93AE),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Color(0xFFD6E1EE)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: _backToLogin,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _blue,
                                  minimumSize: const Size.fromHeight(48),
                                  side: const BorderSide(
                                    color: _blue,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Quay lại đăng nhập',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'BeVietnamPro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
