import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profile_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/create_patient_profile_page.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/select_patient_profile_page.dart';
import 'package:flutter_application_4/features/profile/presentation/widgets/patient_profile_additional_fields.dart';

void main() {
  for (final document in ['nationalId', 'personalId', 'passport']) {
    testWidgets('One $document is sufficient and empty documents are rejected', (
      tester,
    ) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: key,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: const PatientProfileAdditionalFields(),
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.text('Vui lòng nhập CCCD, số định danh cá nhân hoặc hộ chiếu.'),
        findsOneWidget,
      );
      final field = find.byKey(ValueKey(document));
      await tester.ensureVisible(field);
      await tester.enterText(field, '   ');
      expect(key.currentState!.validate(), isFalse);
      await tester.enterText(
        field,
        document == 'passport' ? 'DEMO12345' : '000000000001',
      );
      await tester.pump();
      expect(key.currentState!.validate(), isTrue);
      await tester.ensureVisible(field);
      await tester.enterText(field, '123');
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.text(
          document == 'passport'
              ? 'Hộ chiếu phải có 6–20 chữ cái hoặc chữ số, không chứa khoảng trắng.'
              : '${document == 'nationalId' ? 'CCCD' : 'Số định danh cá nhân'} phải gồm đúng 12 chữ số.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        field,
        document == 'passport' ? 'DEMO12345' : '000000000001',
      );
      expect(key.currentState!.validate(), isTrue);
      await tester.pump();
      expect(
        find.text('Vui lòng nhập CCCD, số định danh cá nhân hoặc hộ chiếu.'),
        findsNothing,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('contactEmail')));
      await tester.enterText(
        find.byKey(const ValueKey('contactEmail')),
        'invalid',
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Email không hợp lệ.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('contactEmail')),
        'demo@example.com',
      );
      expect(key.currentState!.validate(), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Profile card masks phone, returns selected entity and opens create page',
    (tester) async {
      size(tester, const Size(412, 915));
      Patient? selected;
      var homeTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SelectPatientProfilePage(
            profiles: PatientProfileDemoData.profiles,
            onProfileSelected: (patient) => selected = patient,
            onHome: () => homeTapped = true,
            isDemo: true,
          ),
        ),
      );
      expect(find.text('090****123'), findsOneWidget);
      expect(find.text('0900000123'), findsNothing);
      await tester.tap(find.text('NGUYỄN MINH AN'));
      expect(selected, same(PatientProfileDemoData.profiles.first));
      await tester.tap(find.byTooltip('Về trang chủ'));
      expect(homeTapped, isTrue);
      await tester.tap(find.text('Thêm mới hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePatientProfilePage), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Chọn hồ sơ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty state opens form and does not add an unsaved profile', (
    tester,
  ) async {
    size(tester, const Size(320, 700));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SelectPatientProfilePage(
          profiles: const [],
          onProfileSelected: (_) {},
          onHome: () {},
        ),
      ),
    );
    expect(
      find.text(
        'Bạn chưa có hồ sơ khám bệnh. Hãy tạo hồ sơ để tiếp tục đặt khám.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Tạo hồ sơ khám bệnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TẠO HỒ SƠ KHÁM BỆNH'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập Họ và chữ lót.'), findsOneWidget);
    expect(find.text('Vui lòng nhập Tên bệnh nhân.'), findsOneWidget);
    expect(
      find.text('Thông tin hợp lệ. Chức năng lưu hồ sơ sẽ được tích hợp sau.'),
      findsNothing,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Thêm mới hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Form validates all selections, date picker and keyboard layout',
    (tester) async {
      size(tester, const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CreatePatientProfilePage(),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('familyName')),
        'Nguyễn Minh',
      );
      await tester.enterText(find.byKey(const ValueKey('givenName')), 'An');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Chọn ngày sinh'));
      await tester.tap(find.byTooltip('Chọn ngày sinh'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        picker.lastDate.isAfter(DateUtils.dateOnly(DateTime.now())),
        isFalse,
      );
      await tester.tap(find.text('Chọn').last);
      await tester.pumpAndSettle();

      Future<void> choose(String label, String value) async {
        final dropdown = find.byKey(ValueKey(label));
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      await choose('Dân tộc', 'Kinh');
      await tester.ensureVisible(find.byType(RadioGroup<String>));
      await tester.tap(find.text('Nam'));
      await tester.pumpAndSettle();
      await choose('Nghề nghiệp', 'Hưu trí');
      await choose('Quan hệ với chủ tài khoản', 'Tôi');
      await tester.ensureVisible(find.byKey(const ValueKey('passport')));
      await tester.enterText(
        find.byKey(const ValueKey('passport')),
        'DEMO12345',
      );
      await tester.tap(find.text('TẠO HỒ SƠ KHÁM BỆNH'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Thông tin hợp lệ. Chức năng lưu hồ sơ sẽ được tích hợp sau.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CreatePatientProfilePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
