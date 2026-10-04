import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/profile_page.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    testWidgets('Profile scrolls with long data at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <String>[];
      var loggedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(1.5),
              ),
              child: ProfilePage(
                fullName: 'Nguyễn Hoàng Minh Anh với họ tên bệnh nhân dài',
                email: 'benhnhan.email.rat.dai.de.kiem.tra.layout@example.com',
                onOpen: opened.add,
                onLogout: () => loggedOut = true,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      for (final title in [
        'Thông tin bệnh nhân',
        'Hồ sơ cá nhân',
        'Đổi mật khẩu',
        'Cài đặt',
        'Chính sách & điều khoản',
        'Hướng dẫn sử dụng',
        'Liên hệ / Hỗ trợ',
      ]) {
        final row = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getRect(row).centerRight - const Offset(8, 0),
        );
        expect(opened.last, title);
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất'));
      expect(loggedOut, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
