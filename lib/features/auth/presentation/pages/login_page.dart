import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../validators/auth_validators.dart';

import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _blue = Color(0xFF0060EF);
  static const _navy = Color(0xFF143D70);
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
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
    final authProvider = context.watch<AuthProvider>();
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
                              const Text(
                                'Đăng nhập tài khoản',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'BeVietnamPro',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Chào mừng bạn quay trở lại',
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
                                        if (authProvider.status ==
                                                AuthStatus.error &&
                                            authProvider.errorMessage != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEBEE),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFFFCDD2),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    authProvider.errorMessage!,
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                      fontFamily:
                                                          'BeVietnamPro',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        _label('Email'),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          decoration: _decoration(
                                            'Nhập email...',
                                            Icons.email_outlined,
                                          ),
                                          validator: AuthValidators.email,
                                        ),
                                        const SizedBox(height: 20),
                                        _label('Mật khẩu'),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onFieldSubmitted: (_) => _login(),
                                          decoration: _decoration(
                                            'Nhập mật khẩu...',
                                            Icons.lock_outline_rounded,
                                            suffix: IconButton(
                                              tooltip: _obscurePassword
                                                  ? 'Hiện mật khẩu'
                                                  : 'Ẩn mật khẩu',
                                              onPressed: () => setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              ),
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: const Color(0xFF7A8DA6),
                                              ),
                                            ),
                                          ),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                              ? 'Vui lòng nhập mật khẩu'
                                              : null,
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ForgotPasswordPage(),
                                                  ),
                                                ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _blue,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: const Text(
                                              'Quên mật khẩu?',
                                              style: TextStyle(
                                                fontFamily: 'BeVietnamPro',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
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
                                             onPressed: authProvider.isLoading
                                                 ? null
                                                 : _login,
                                             style: ElevatedButton.styleFrom(
                                               backgroundColor:
                                                   Colors.transparent,
                                               shadowColor: Colors.transparent,
                                               foregroundColor: Colors.white,
                                               disabledForegroundColor:
                                                   Colors.white70,
                                               minimumSize:
                                                   const Size.fromHeight(54),
                                               shape: RoundedRectangleBorder(
                                                 borderRadius:
                                                     BorderRadius.circular(12),
                                               ),
                                               elevation: 0,
                                             ),
                                             child: authProvider.isLoading
                                                 ? const SizedBox(
                                                     width: 24,
                                                     height: 24,
                                                     child:
                                                         CircularProgressIndicator(
                                                       color: Colors.white,
                                                       strokeWidth: 2.5,
                                                     ),
                                                   )
                                                 : const Text(
                                                     'Đăng nhập',
                                                     style: TextStyle(
                                                       fontFamily:
                                                           'BeVietnamPro',
                                                       fontSize: 18,
                                                       fontWeight:
                                                           FontWeight.w700,
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
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                ),
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
                                  'Đăng ký tài khoản mới',
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
