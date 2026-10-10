import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_profile_information_page.dart';

void main() {
  testWidgets('Read-only information shows supplied values and full phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PatientProfileInformationPage(
          patient: Patient(
            id: 'DEMO-INFO',
            authUserId: 'demo',
            fullName: 'Nguyễn Minh Anh',
            phone: '0910000678',
            email: 'demo@example.com',
            isActive: true,
            dateOfBirth: DateTime(2005, 4, 14),
            gender: 'FEMALE',
            relationshipToAccountHolder: 'Con',
            nationalId: 'DEMO-CCCD',
            country: 'Việt Nam',
            occupation: 'Sinh viên',
            address: 'Địa chỉ minh họa',
          ),
        ),
      ),
    );
    expect(find.text('NGUYỄN MINH ANH'), findsOneWidget);
    expect(find.text('Nữ • 14/04/2005'), findsOneWidget);
    expect(find.text('14/04/2005'), findsOneWidget);
    expect(find.text('DEMO-CCCD'), findsOneWidget);
    expect(find.text('Con'), findsOneWidget);
    await tester.ensureVisible(find.text('Địa chỉ minh họa'));
    await tester.pumpAndSettle();
    expect(find.text('0910000678'), findsOneWidget);
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(find.text('Cập nhật'), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Missing fields use fallback and geographic fields compose address',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PatientProfileInformationPage(
            patient: PatientProfilesDemoData.profiles.first,
          ),
        ),
      );
      expect(find.text('Chưa cập nhật'), findsWidgets);
      await tester.ensureVisible(find.text('Địa chỉ'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PatientProfileInformationPage(
            patient: Patient(
              id: 'demo',
              authUserId: 'demo',
              fullName: 'Minh họa',
              phone: '',
              email: '',
              isActive: true,
              ward: 'Phường minh họa',
              district: 'Quận minh họa',
              province: 'Thành phố minh họa',
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.text('Phường minh họa, Quận minh họa, Thành phố minh họa'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Long name and address fit small screens and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final address = List.filled(8, 'Địa chỉ minh họa dài').join(', ');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: PatientProfileInformationPage(
          patient: Patient(
            id: 'demo',
            authUserId: 'demo',
            fullName: 'Nguyễn Thị Hoàng Minh Anh tên hồ sơ dài',
            phone: '0910000678',
            email: '',
            isActive: true,
            address: address,
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text(address));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
