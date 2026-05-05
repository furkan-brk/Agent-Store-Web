// v3.11.4: covers TrialEndCta button visibility logic.

import 'package:agent_store/features/agent_detail/widgets/trial_end_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows Buy now + Top up secondary when user has enough credits',
      (tester) async {
    var buyTapped = false;
    var topUpTapped = false;
    await tester.pumpWidget(_wrap(TrialEndCta(
      priceCredits: 10,
      userCredits: 50,
      onBuy: () => buyTapped = true,
      onTopUp: () => topUpTapped = true,
    )));
    expect(find.text('Buy now'), findsOneWidget);
    expect(find.text('Top up'), findsOneWidget);
    await tester.tap(find.text('Buy now'));
    expect(buyTapped, isTrue);
    expect(topUpTapped, isFalse);
  });

  testWidgets('shows Top up credits primary when user lacks credits',
      (tester) async {
    var topUpTapped = false;
    await tester.pumpWidget(_wrap(TrialEndCta(
      priceCredits: 10,
      userCredits: 3,
      onBuy: () {},
      onTopUp: () => topUpTapped = true,
    )));
    expect(find.text('Top up credits'), findsOneWidget,
        reason: 'insufficient credits → primary CTA is Top Up');
    expect(find.text('Buy now'), findsNothing);
    await tester.tap(find.text('Top up credits'));
    expect(topUpTapped, isTrue);
  });
}
