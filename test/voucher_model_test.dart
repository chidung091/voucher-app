import 'package:flutter_test/flutter_test.dart';
import 'package:voucher_app/features/vouchers/models/voucher.dart';

void main() {
  test('Voucher.fromJson parses payload', () {
    const json = {
      'id': 10,
      'title': 'Spring bonus',
      'completed': true,
    };

    final voucher = Voucher.fromJson(json);

    expect(voucher.id, 10);
    expect(voucher.title, 'Spring bonus');
    expect(voucher.isRedeemed, true);
  });
}
