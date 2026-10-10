import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_profiles_page.dart';
import 'package:flutter_application_4/features/profile/presentation/widgets/patient_profile_card.dart';

void main() {
  testWidgets('Profiles reuse cards, mask phones and keep taps on this page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PatientProfilesPage(
          profiles: PatientProfilesDemoData.profiles,
          isDemo: true,
        ),
      ),
    );
    expect(find.byType(PatientProfileCard), findsNWidgets(3));
    expect(find.text('091****678'), findsNWidgets(2));
    expect(find.text('0910000678'), findsNothing);
    expect(find.text('Tôi'), findsOneWidget);
    expect(find.text('Con'), findsOneWidget);
    expect(find.text('Mẹ'), findsOneWidget);
    expect(find.text('Liên kết hồ sơ'), findsNothing);
    await tester.tap(find.text('NGUYỄN VĂN AN'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chức năng'), findsOneWidget);
    expect(find.text('NGUYỄN VĂN AN • DEMO-BN001'), findsOneWidget);
    expect(find.text('HỒ SƠ SỨC KHỎE'), findsOneWidget);
    expect(find.text('KẾT QUẢ CẬN LÂM SÀNG'), findsOneWidget);
    expect(find.text('HÌNH ẢNH CHỤP (PACS)'), findsOneWidget);
    expect(find.text('PHIẾU ĐĂNG KÝ KHÁM'), findsOneWidget);
    expect(find.text('THÔNG TIN HỒ SƠ'), findsOneWidget);
    await tester.tap(find.text('HỒ SƠ SỨC KHỎE'));
    await tester.pumpAndSettle();
    expect(find.text('(DEMO-BN001)'), findsOneWidget);
    expect(find.text('Khám bệnh'), findsOneWidget);
    expect(find.text('Không có kết quả!'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KẾT QUẢ CẬN LÂM SÀNG'));
    await tester.pumpAndSettle();
    expect(find.text('Kết quả cận lâm sàng'), findsOneWidget);
    expect(find.text('NGUYỄN VĂN AN (DEMO-BN001)'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chức năng'), findsOneWidget);
    await tester.tap(find.text('HÌNH ẢNH CHỤP (PACS)'));
    await tester.pumpAndSettle();
    expect(find.text('Hình ảnh chụp (PACS)'), findsOneWidget);
    expect(find.text('NGUYỄN VĂN AN (DEMO-BN001)'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chức năng'), findsOneWidget);
    await tester.ensureVisible(find.text('PHIẾU ĐĂNG KÝ KHÁM'));
    await tester.tap(find.text('PHIẾU ĐĂNG KÝ KHÁM'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử đặt khám'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chức năng'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chức năng'), findsNothing);
    expect(find.text('Chọn chuyên khoa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty profiles show an empty state without actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PatientProfilesPage(profiles: []),
      ),
    );
    expect(find.text('Bạn chưa có hồ sơ người bệnh.'), findsOneWidget);
    expect(find.byType(PatientProfileCard), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Function sheet scrolls on small screens and uses selected profile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PatientProfilesPage(
            profiles: PatientProfilesDemoData.profiles,
          ),
        ),
      );
      await tester.tap(find.text('NGUYỄN MINH ANH'));
      await tester.pumpAndSettle();
      expect(find.text('NGUYỄN MINH ANH • DEMO-BN002'), findsOneWidget);
      await tester.ensureVisible(find.text('THÔNG TIN HỒ SƠ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('THÔNG TIN HỒ SƠ'));
      await tester.pumpAndSettle();
      expect(find.text('NGUYỄN MINH ANH'), findsOneWidget);
      expect(find.text('THÔNG TIN CÁ NHÂN'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Chọn chức năng'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Chọn chức năng'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Long names fit small screens and many profiles can scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profiles = List.generate(
      20,
      (index) => Patient(
        id: 'DEMO-$index',
        authUserId: 'demo',
        fullName: 'Nguyễn Thị Hoàng Minh Anh tên hồ sơ dài $index',
        phone: '0910000678',
        email: '',
        isActive: true,
        relationshipToAccountHolder: 'Anh / Chị / Em',
      ),
    );
    Patient? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PatientProfilesPage(
          profiles: profiles,
          onProfileTap: (p) => tapped = p,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('DEMO-19'), 400);
    await tester.tap(find.text('DEMO-19'));
    expect(tapped, same(profiles.last));
    expect(tester.takeException(), isNull);
  });
}
