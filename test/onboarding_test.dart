import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/onboarding/data/datasources/app_preferences.dart';
import 'package:flutter_application_4/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter_application_4/features/onboarding/presentation/pages/splash_page.dart';

class StorageState {
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? pendingWrite;
}

class MemoryPreferences implements SharedPreferencesAsync {
  final Map<String, bool> values = {};
  final state = StorageState();

  @override
  Future<bool?> getBool(String key) async {
    if (state.failRead) throw StateError('Read failed');
    return values[key];
  }

  @override
  Future<void> setBool(String key, bool value) async {
    if (state.failWrite) throw StateError('Write failed');
    if (state.pendingWrite != null) await state.pendingWrite!.future;
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class UnusedAuthRepository implements AuthRepository {
  @override
  Stream<String?> get authStateChanges => const Stream<String?>.empty();

  @override
  Future<UserEntity?> getCurrentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget testApp(AppPreferences preferences) => ChangeNotifierProvider(
  create: (_) => AuthController(authRepo: UnusedAuthRepository()),
  child: MaterialApp(
    home: SplashPage(preferences: OnboardingRepositoryImpl(preferences)),
  ),
);

Future<void> finishSplash(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Missing preference defaults to false; completion stores only the flag',
    () async {
      final storage = MemoryPreferences();
      final preferences = AppPreferences(preferences: storage);
      expect(await preferences.isOnboardingCompleted(), isFalse);
      await preferences.completeOnboarding();
      expect(storage.values, {'onboardingCompleted': true});
      expect(
        await AppPreferences(preferences: storage).isOnboardingCompleted(),
        isTrue,
      );
    },
  );

  for (final completed in <bool?>[null, false, true]) {
    testWidgets('Splash opens login with onboarding flag $completed', (
      tester,
    ) async {
      final storage = MemoryPreferences();
      if (completed != null) storage.values['onboardingCompleted'] = completed;
      await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      await finishSplash(tester);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
        isFalse,
      );
    });
  }

  testWidgets('Splash opens login even when preference reads fail', (
    tester,
  ) async {
    final storage = MemoryPreferences();
    storage.state.failRead = true;
    await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
    await finishSplash(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });
}
