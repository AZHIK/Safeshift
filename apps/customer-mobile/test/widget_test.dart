// TODO: expand into real widget tests during the mock UI phase.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/app.dart';

void main() {
  testWidgets('SafeShiftApp builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SafeShiftApp()));
    expect(find.byType(SafeShiftApp), findsOneWidget);
  });

  testWidgets('Unauthenticated app starts on the login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SafeShiftApp()));
    await tester.pumpAndSettle();
    expect(find.text('SafeShift'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
