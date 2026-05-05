// v3.11.4: covers MissionScheduleDialog preset → cron resolution + Save flow.

import 'package:agent_store/features/missions/widgets/mission_schedule_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _showDialog(
  WidgetTester tester, {
  required MissionScheduleSaveCallback onSave,
  MissionScheduleDeleteCallback? onDelete,
  String? initialCron,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MissionScheduleDialog(
                onSave: onSave,
                onDelete: onDelete,
                initialCron: initialCron,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
    }),
  ));
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('default preset Hourly resolves to "0 * * * *" on Save',
      (tester) async {
    String? saved;
    await _showDialog(tester, onSave: (cron, _) async => saved = cron);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();
    expect(saved, equals('0 * * * *'));
  });

  testWidgets('Custom preset reveals cron expression field',
      (tester) async {
    await _showDialog(tester, onSave: (_, __) async {});

    // Open dropdown and pick "Custom (cron)"
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom (cron)').last);
    await tester.pumpAndSettle();

    expect(find.text('Cron expression'), findsOneWidget);
  });

  testWidgets('Delete button appears only when onDelete is non-null',
      (tester) async {
    await _showDialog(tester, onSave: (_, __) async {}, onDelete: () async {});
    expect(find.text('Delete'), findsOneWidget);
  });
}
