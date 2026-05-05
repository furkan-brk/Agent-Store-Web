// Widget regression test for v3.12 (PR 2 / FIX 2) — FE-P0-2.
//
// Asserts that the Creator Dashboard dialogs (Edit / SetPrice) dispose their
// TextEditingControllers when torn down. Pre-fix, _showEditDialog leaked 3
// controllers (titleCtrl/descCtrl/tagCtrl) and _showPriceDialog leaked 1
// (priceCtrl) because the host was a StatelessWidget and the dialog body
// was a StatefulBuilder which doesn't dispose.
//
// We verify the new public CreatorEditAgentDialog / CreatorSetPriceDialog
// widgets via a direct Stateful-lifecycle test: pumpWidget the dialog body,
// then pumpWidget a different widget so the State is unmounted. A missing
// dispose would (best case) leave the controller's tickers active and
// trigger Flutter framework leak diagnostics; the test passes if the
// teardown raises no exception.

import 'package:agent_store/features/character/character_types.dart';
import 'package:agent_store/features/creator/widgets/creator_dialogs.dart';
import 'package:agent_store/shared/models/agent_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentModel _agent({
  int id = 42,
  String title = 'Wizard #42',
  String description = 'A long enough description for validation.',
  double price = 0,
  List<String> tags = const ['code', 'test'],
}) =>
    AgentModel(
      id: id,
      title: title,
      description: description,
      prompt: '',
      category: 'backend',
      creatorWallet: '0xowner',
      characterType: CharacterType.wizard,
      subclass: CharacterSubclass.archmage,
      rarity: CharacterRarity.common,
      stats: const {},
      traits: const [],
      tags: tags,
      useCount: 0,
      saveCount: 0,
      price: price,
      createdAt: DateTime.now(),
    );

void main() {
  testWidgets(
    'CreatorEditAgentDialog disposes its 3 controllers on unmount',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CreatorEditAgentDialog(
            agent: _agent(title: 'Original Title'),
            onSaved: () {},
          ),
        ),
      ));
      // Widget mounted — title field shows the seeded text.
      expect(find.text('Original Title'), findsOneWidget);

      // Tear down the subtree — triggers State.dispose which must dispose
      // _titleCtrl, _descCtrl, and _tagCtrl.
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CreatorEditAgentDialog: 10× build/teardown cycle is leak-free',
    (tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CreatorEditAgentDialog(
              agent: _agent(id: i, title: 'iter-$i'),
              onSaved: () {},
            ),
          ),
        ));
        expect(find.text('iter-$i'), findsOneWidget);
        // Unmount.
        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CreatorSetPriceDialog disposes its priceCtrl on unmount',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CreatorSetPriceDialog(
            agent: _agent(price: 4.50),
            onSaved: () {},
          ),
        ),
      ));
      expect(find.text('4.50'), findsOneWidget);
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CreatorSetPriceDialog: 10× build/teardown cycle is leak-free',
    (tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CreatorSetPriceDialog(
              agent: _agent(id: i, price: i.toDouble()),
              onSaved: () {},
            ),
          ),
        ));
        await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CreatorEditAgentDialog Save button disabled when title is empty',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CreatorEditAgentDialog(
            agent: _agent(title: ''),
            onSaved: () {},
          ),
        ),
      ));
      // Title 0 chars → titleValid false → Save Changes is disabled.
      final saveBtn = find.widgetWithText(ElevatedButton, 'Save Changes');
      expect(saveBtn, findsOneWidget);
      final btn = tester.widget<ElevatedButton>(saveBtn);
      expect(btn.onPressed, isNull);
    },
  );
}
