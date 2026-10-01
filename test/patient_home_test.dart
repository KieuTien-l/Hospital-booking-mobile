import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/patient_home_view.dart';

void main() {
  testWidgets('Patient home supports small screens, search and navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PatientHomeView(
          fullName: 'Nguyễn An',
          onLogout: () => loggedOut = true,
        ),
      ),
    );
    expect(find.text('Bệnh viện Quốc tế Meridian'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Đặt khám');
    await tester.pump();
    expect(find.text('Đặt khám', findRichText: false).last, findsOneWidget);
    expect(find.text('Hồ sơ sức khỏe'), findsNothing);
    await tester.tap(find.text('Đặt khám', findRichText: false).last);
    await tester.pumpAndSettle();
    expect(
      find.text('Chức năng đang được hoàn thiện. Vui lòng quay lại sau.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có thông báo mới.'), findsOneWidget);
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sức khỏe'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    expect(loggedOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}

