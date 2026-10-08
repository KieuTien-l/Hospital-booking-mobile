import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/specialties/domain/repositories/specialty_repository.dart';
import 'package:flutter_application_4/features/specialties/presentation/controllers/specialty_controller.dart';
import 'package:flutter_application_4/features/specialties/presentation/pages/specialty_list_page.dart';

class _Repository implements SpecialtyRepository {
  final stream = StreamController<List<Specialty>>.broadcast();
  int calls = 0;
  @override
  Stream<List<Specialty>> watchSpecialties() {
    calls++;
    return stream.stream;
  }
}

void main() {
  test('Vietnamese search normalizes accents, combining marks and casing', () {
    expect(normalizeSpecialtySearch('  ĐAU CỘT SỐNG '), 'dau cot song');
    expect(normalizeSpecialtySearch('Da\u0301 lie\u0302\u0303u'), 'da lieu');
  });

  testWidgets('Loading, empty, error and retry use the existing controller', (
    tester,
  ) async {
    final repository = _Repository();
    addTearDown(repository.stream.close);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SpecialtyController(repository),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SpecialtyListPage(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.stream.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có chuyên khoa đang hoạt động.'), findsOneWidget);
    repository.stream.addError(Exception('permission-denied'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Thử lại'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(repository.calls, 2);
    repository.stream.add(const []);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pixel 7 layout supports search, expansion and selected entity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    addTearDown(repository.stream.close);
    Specialty? selected;
    final description = List.filled(
      15,
      'Khám và tư vấn các bệnh về da.',
    ).join(' ');
    final specialty = Specialty(
      id: 'skin',
      name: 'Da liễu',
      description: description,
      isActive: true,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SpecialtyController(repository),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: SpecialtyListPage(
            onSpecialtySelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pump();
    repository.stream.add([
      specialty,
      const Specialty(
        id: 'heart',
        name: 'Tim mạch',
        description: 'Khám tim.',
        isActive: true,
      ),
      const Specialty(
        id: 'inactive',
        name: 'Ẩn',
        description: '',
        isActive: false,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Ẩn'), findsNothing);
    await tester.enterText(find.byType(TextField), 'DA LIEU');
    await tester.pump();
    expect(find.text('DA LIỄU'), findsOneWidget);
    expect(find.text('TIM MẠCH'), findsNothing);
    await tester.tap(find.text('Xem thêm'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
    expect(selected, isNull);
    await tester.tap(find.text('Thu gọn'));
    await tester.pump();
    expect(tester.widget<Text>(find.text(description)).maxLines, 2);
    await tester.tap(find.text('DA LIỄU'));
    await tester.pump();
    expect(selected?.id, 'skin');
    await tester.enterText(find.byType(TextField), 'khong co');
    await tester.pump();
    expect(find.text('Không tìm thấy chuyên khoa phù hợp.'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pump();
    expect(find.text('TIM MẠCH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
