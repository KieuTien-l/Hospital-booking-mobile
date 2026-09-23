import 'package:flutter/material.dart';

import 'core/themes/app_theme.dart';
import 'features/onboarding/presentation/pages/splash_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: SplashPage(),
    );
  }
}
