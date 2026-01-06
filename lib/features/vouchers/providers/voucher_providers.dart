import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voucher_repository.dart';
import '../models/voucher.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) {
  return VoucherRepository();
});

final vouchersProvider = FutureProvider<List<Voucher>>((ref) async {
  final repository = ref.watch(voucherRepositoryProvider);
  return repository.fetchVouchers();
});
