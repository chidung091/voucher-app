import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'providers/voucher_providers.dart';

class VouchersScreen extends ConsumerWidget {
  const VouchersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final vouchersAsync = ref.watch(vouchersProvider);
    final currency = NumberFormat.simpleCurrency(
      name: 'VND',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.voucherListTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            localizations.voucherListSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: vouchersAsync.when(
              loading: () => const LoadingView(),
              error: (error, stackTrace) => ErrorView(
                title: localizations.errorsTitle,
                message: error.toString(),
                retryLabel: localizations.tryAgain,
                onRetry: () => ref.invalidate(vouchersProvider),
              ),
              data: (vouchers) => ListView.separated(
                itemCount: vouchers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final voucher = vouchers[index];
                  return Card(
                    child: ListTile(
                      onTap: () => context.go('/vouchers/${voucher.id}'),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            voucher.imageAsset,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(voucher.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (voucher.subtitle.isNotEmpty)
                            Text(voucher.subtitle),
                          Text(currency.format(voucher.priceVnd)),
                          const SizedBox(height: 4),
                          Text(
                            voucher.isRedeemed
                                ? localizations.voucherStatusRedeemed
                                : localizations.voucherStatusActive,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () {},
                        child: Text(
                          voucher.isRedeemed
                              ? localizations.voucherActionView
                              : localizations.voucherActionRedeem,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
