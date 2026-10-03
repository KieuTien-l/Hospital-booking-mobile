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

  testWidgets('First launch completes onboarding; a new app skips it', (
    tester,
  ) async {
    final storage = MemoryPreferences();
    await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
    await finishSplash(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(storage.values, isEmpty);

    storage.state.pendingWrite = Completer<void>();
    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Đang lưu...'), findsOneWidget);
    storage.state.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(storage.values['onboardingCompleted'], isTrue);
    expect(
      Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
      isFalse,
    );

    // Recreate the widget tree and preference service with the same storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
    await finishSplash(tester);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('Explicit false shows onboarding', (tester) async {
    final storage = MemoryPreferences()..values['onboardingCompleted'] = false;
    await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
    await finishSplash(tester);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets(
    'Read failure falls back to onboarding; write failure permits retry',
    (tester) async {
      final storage = MemoryPreferences();
      storage.state
        ..failRead = true
        ..failWrite = true;
      await tester.pumpWidget(testApp(AppPreferences(preferences: storage)));
      await finishSplash(tester);
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(storage.values, isEmpty);
      expect(
        find.text('Chưa thể lưu trạng thái. Vui lòng thử lại.'),
        findsOneWidget,
      );
      storage.state.failWrite = false;
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
}
