import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/doctors/presentation/models/doctor_detail_demo_data.dart';
import 'package:flutter_application_4/features/doctors/presentation/models/doctor_detail_ui_model.dart';
import 'package:flutter_application_4/features/doctors/presentation/pages/doctor_detail_page.dart';

void main() {
  final demo = DoctorDetailDemoData.forDoctor(
    id: 'demo-morning',
    name: 'Bác sĩ A',
    specialty: 'Da liễu',
    location: 'Phòng 66',
    session: 'Buổi sáng',
  );

  Future<void> show(
    WidgetTester tester,
    DoctorDetailUiModel doctor, {
    Size size = const Size(412, 915),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: DoctorDetailPage(doctor: doctor),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Demo identity, placeholder, schedule and collapsible sections', (
    tester,
  ) async {
    await show(tester, demo);
    expect(find.text('Bác sĩ A'), findsOneWidget);
    expect(find.text('Thông tin minh họa'), findsNothing);
    expect(find.text('Bác sĩ chuyên khoa II'), findsNothing);
    expect(find.text('Nam'), findsOneWidget);
    expect(find.byIcon(Icons.male), findsNothing);
    expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
    expect(find.text(demo.introduction!), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
    expect(find.text('Phòng 66'), findsOneWidget);
    await tester.tap(find.text('Lịch khám bệnh'));
    await tester.pumpAndSettle();
    expect(find.text('Phòng 66'), findsNothing);
    for (final title in [
      'Quá trình đào tạo',
      'Quá trình công tác',
      'Hiệp hội chuyên môn',
      'Công trình nghiên cứu',
    ]) {
      final finder = find.text(title);
      await tester.scrollUntilVisible(finder, 150);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      final content = {
        'Quá trình đào tạo': 'Hoàn thành đào tạo chuyên khoa II',
        'Quá trình công tác': 'Kinh nghiệm giảng dạy',
        'Hiệp hội chuyên môn': '• Hội chuyên ngành minh họa A',
        'Công trình nghiên cứu':
            'Nghiên cứu minh họa về chăm sóc người bệnh ngoại trú',
      }[title]!;
      expect(find.text(content), findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(find.text(content), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty optional sections are hidden', (tester) async {
    await show(
      tester,
      const DoctorDetailUiModel(
        id: 'empty',
        name: 'Bác sĩ mới',
        specialty: 'Nội khoa',
      ),
    );
    expect(find.text('Chưa có thông tin lịch khám.'), findsOneWidget);
    expect(find.text('Quá trình đào tạo'), findsNothing);
    expect(find.text('Quá trình công tác'), findsNothing);
    expect(find.text('Hiệp hội chuyên môn'), findsNothing);
    expect(find.text('Công trình nghiên cứu'), findsNothing);
    expect(find.text('Thông tin minh họa'), findsNothing);
  });

  for (final size in [const Size(412, 915), const Size(320, 700)]) {
    testWidgets('Long content and expanded sections fit $size at large text', (
      tester,
    ) async {
      await show(tester, demo, size: size, scale: 1.5);
      for (final title in [
        'Quá trình đào tạo',
        'Quá trình công tác',
        'Hiệp hội chuyên môn',
        'Công trình nghiên cứu',
      ]) {
        await tester.scrollUntilVisible(find.text(title), 180);
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
