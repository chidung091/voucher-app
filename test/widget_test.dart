import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/app.dart';

void main() {
  testWidgets('App builds and shows splash content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoucherApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Voucher App'), findsOneWidget);
  });
}
