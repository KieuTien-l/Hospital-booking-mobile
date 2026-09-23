import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _blue = Color(0xFF0060EF);
  static const _navy = Color(0xFF143D70);
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptedTerms = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _backToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  static const _passwordHint = Text(
    'Mật khẩu tối đa 10 ký tự',
    style: TextStyle(
      fontFamily: 'BeVietnamPro',
      fontSize: 12,
      color: Color(0xFF7D93AE),
    ),
  );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _register() {
    if (!_acceptedTerms) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _showMessage('Chức năng đăng ký tài khoản chưa được kết nối.');
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
                              const Text(
                                'Đăng ký tài khoản',
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
                                'Tạo tài khoản để chăm sóc sức khỏe',
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
                                        _label('Họ và tên'),
                                        TextFormField(
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(
                                                r'[\p{L}\p{M} ]',
                                                unicode: true,
                                              ),
                                            ),
                                          ],
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.name,
                                          ],
                                          decoration: _decoration(
                                            'Nhập họ và tên...',
                                            Icons.person_outline_rounded,
                                          ),
                                          validator: (value) =>
                                              value == null ||
                                                  value.trim().isEmpty
                                              ? 'Vui lòng nhập họ và tên'
                                              : null,
                                        ),
                                        const SizedBox(height: 20),
                                        _label('Số điện thoại'),
                                        TextFormField(
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                              10,
                                            ),
                                          ],
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.telephoneNumber,
                                          ],
                                          decoration: _decoration(
                                            'Nhập số điện thoại...',
                                            Icons.phone_android_rounded,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Vui lòng nhập số điện thoại';
                                            }
                                            if (!RegExp(r'^[0-9]{10}$')
                                                .hasMatch(value)) {
                                              return 'Số điện thoại phải có đúng 10 số';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        _label('Mật khẩu'),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(
                                              10,
                                            ),
                                          ],
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.newPassword,
                                          ],

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
                                          ).copyWith(helper: _passwordHint),
                                          errorBuilder: (context, errorText) =>
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _passwordHint,
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    errorText,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          'BeVietnamPro',
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          validator: (value) =>
                                              value == null ||
                                                  value.trim().isEmpty
                                              ? 'Vui lòng nhập mật khẩu'
                                              : null,
                                        ),
                                        const SizedBox(height: 20),
                                        _label('Xác nhận mật khẩu'),
                                        TextFormField(
                                          obscureText: _obscureConfirmation,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          inputFormatters: [
                                            LengthLimitingTextInputFormatter(
                                              10,
                                            ),
                                          ],
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _register(),
                                          decoration: _decoration(
                                            'Nhập lại mật khẩu...',
                                            Icons.lock_outline_rounded,
                                            suffix: IconButton(
                                              tooltip: _obscureConfirmation
                                                  ? 'Hiện xác nhận mật khẩu'
                                                  : 'Ẩn xác nhận mật khẩu',
                                              onPressed: () => setState(
                                                () => _obscureConfirmation =
                                                    !_obscureConfirmation,
                                              ),
                                              icon: Icon(
                                                _obscureConfirmation
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: const Color(0xFF7A8DA6),
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Vui lòng xác nhận mật khẩu';
                                            }
                                            if (value !=
                                                _passwordController.text) {
                                              return 'Mật khẩu xác nhận không khớp';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        CheckboxListTile(
                                          value: _acceptedTerms,
                                          onChanged: (value) => setState(
                                            () =>
                                                _acceptedTerms = value ?? false,
                                          ),
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: _blue,
                                          checkColor: Colors.white,
                                          title: const Text(
                                            'Tôi đã đọc, đồng ý với các điều khoản sử dụng và cho phép Bệnh viện sử dụng thông tin, dữ liệu phục vụ khám chữa bệnh',
                                            style: TextStyle(
                                              fontFamily: 'BeVietnamPro',
                                              fontSize: 12,
                                              height: 1.6,
                                              color: Color(0xFF384C5D),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: _acceptedTerms
                                                ? null
                                                : const Color(0xFFE1E7EF),
                                            gradient: _acceptedTerms
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF258CE8),
                                                      Color(0xFF0055E4),
                                                    ],
                                                  )
                                                : null,
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _acceptedTerms
                                                ? _register
                                                : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  Colors.transparent,
                                              disabledForegroundColor:
                                                  const Color(0xFF8A98AA),
                                              minimumSize:
                                                  const Size.fromHeight(54),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Đăng ký',
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
                                  'Đăng nhập',
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
