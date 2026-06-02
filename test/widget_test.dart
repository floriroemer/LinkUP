import 'package:flutter_test/flutter_test.dart';
import 'package:linkup/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows sequential onboarding flow on launch', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LinkUpApp());
    await tester.pumpAndSettle();

    expect(find.text('LinkUP'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Create new account'), findsNothing);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Create a new account'), findsOneWidget);
    expect(find.text('Load existing account'), findsOneWidget);
  });
}