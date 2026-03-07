// Basic Flutter widget test for RizzRank app.

import 'package:flutter_test/flutter_test.dart';
import 'package:rizzrank/main.dart';

void main() {
  testWidgets('RizzRank app loads and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const RizzRankApp());

    expect(find.text('RizzRank'), findsOneWidget);
    expect(find.text('Phase 1 complete. Firebase initialized.'), findsOneWidget);
  });
}
