import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/admin/data/admin_commands.dart';
import 'package:flutter_application_4/features/admin/presentation/admin_editor.dart';

void main() {
  Finder input(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  testWidgets(
    'editor validates, preserves input on errors, retries the same body using the same key',
    (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AdminEditor(
                    title: 'Tạo chuyên khoa',
                    description: 'Kiểm thử',
                    fields: const [
                      AdminEditField('name', 'Tên chuyên khoa', required: true),
                    ],
                    onSubmit: (values, reason, requestId) async {
                      requests.add(requestId);
                      expect(values['name'], 'Nội tổng quát');
                      expect(reason, 'Tạo danh mục');
                      if (requests.length == 1) {
                        throw const AdminCommandException('Lỗi mạng, thử lại');
                      }
                      return {'id': 'new-specialty'};
                    },
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      await tester.enterText(input('Tên chuyên khoa'), 'Nội tổng quát');
      await tester.enterText(
        input('Lý do thao tác / ghi chú quản trị'),
        'Tạo danh mục',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Lỗi mạng, thử lại'), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Tên chuyên khoa')).controller!.text,
        'Nội tổng quát',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(find.byType(AdminEditor), findsNothing);
    },
  );
  testWidgets('changing data after a failed request generates a new key', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminEditor(
            title: 'Sửa',
            description: 'Kiểm thử',
            fields: const [
              AdminEditField('name', 'Tên', required: true, initial: 'A'),
            ],
            initialReason: 'Điều chỉnh',
            onSubmit: (_, _, requestId) async {
              requests.add(requestId);
              throw const AdminCommandException('Thử lại');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.enterText(input('Tên'), 'B');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(requests[0], isNot(requests[1]));
    await tester.pumpWidget(const SizedBox());
  });
}
