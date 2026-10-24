import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/routes/auth_gate.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/admin_home_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_home_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/patient_home_page.dart';

class MemoryAuthRepository implements AuthRepository {
  UserEntity? user;
  final events = StreamController<String?>.broadcast();

  @override
  Stream<String?> get authStateChanges => events.stream;

  @override
  Future<UserEntity?> getCurrentUser() async => user;

  @override
  Future<UserRole?> getUserRole() async => user?.role;

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    events.add(user!.id);
    return user!;
  }

  @override
  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async => account(UserRole.patient);

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> logout() async {
    user = null;
    events.add(null);
  }
}

UserEntity account(UserRole role, {bool isActive = true}) => UserEntity(
  id: 'user-1',
  email: 'user@example.com',
  fullName: 'Test User',
  phone: '0900000000',
  role: role,
  isActive: isActive,
);

void main() {
  for (final role in UserRole.values) {
    testWidgets('ADM-20: inactive $role never reaches a role workspace', (
      tester,
    ) async {
      final repository = MemoryAuthRepository()
        ..user = account(role, isActive: false);
      final controller = AuthController(authRepo: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(
            home: AuthGate(useLiveCommunications: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(PatientHomePage), findsNothing);
      expect(find.byType(AdminHomePage), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final role in UserRole.values) {
    testWidgets('Login loads profile, routes $role, logout returns to Login', (
      tester,
    ) async {
      final repository = MemoryAuthRepository();
      final controller = AuthController(authRepo: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.events.close);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(
            home: AuthGate(useLiveCommunications: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      repository.user = account(role);
      await controller.login(
        email: 'user@example.com',
        password: 'password123',
      );
      await tester.pumpAndSettle();
      final homeType = switch (role) {
        UserRole.patient => PatientHomePage,
        UserRole.doctor => DoctorHomePage,
        UserRole.admin => AdminHomePage,
      };
      expect(find.byType(homeType), findsOneWidget);
      expect(controller.currentUser?.fullName, 'Test User');

      await controller.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(controller.currentUser, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'Restores an authenticated session and registration stays signed out',
    () async {
      final repository = MemoryAuthRepository()
        ..user = account(UserRole.doctor);
      final controller = AuthController(authRepo: repository);
      addTearDown(controller.dispose);
      addTearDown(repository.events.close);
      await Future<void>.delayed(Duration.zero);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.currentUser?.role, UserRole.doctor);
      await controller.logout();
      expect(
        await controller.register(
          email: 'new@example.com',
          password: 'password123',
          fullName: 'New Patient',
          phone: '',
        ),
        isTrue,
      );
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.currentUser, isNull);
    },
  );
}
