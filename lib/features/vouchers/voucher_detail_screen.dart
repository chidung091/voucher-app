import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import 'models/voucher.dart';
import 'providers/voucher_providers.dart';

class VoucherDetailScreen extends ConsumerWidget {
  const VoucherDetailScreen({super.key, required this.voucherId});

  final int? voucherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (voucherId == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          title: 'Something went wrong',
          message: 'Voucher not found',
          retryLabel: 'Try again',
          onRetry: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final voucherAsync = ref.watch(voucherByIdProvider(voucherId!));
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return voucherAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          title: 'Something went wrong',
          message: error.toString(),
          retryLabel: 'Try again',
          onRetry: () => ref.invalidate(voucherByIdProvider(voucherId!)),
        ),
      ),
      data: (voucher) {
        if (voucher == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              title: 'Something went wrong',
              message: 'Voucher not found',
              retryLabel: 'Try again',
              onRetry: () => Navigator.of(context).maybePop(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Commodity Details'),
            centerTitle: false,
            titleSpacing: 0,
          ),
          body: _VoucherDetailBody(
            voucher: voucher,
            dateFormat: dateFormat,
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size(0, 44),
                backgroundColor: const Color(0xFFF38A21),
              ),
              child: const Text(
                'Redeem Now',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoucherDetailBody extends StatelessWidget {
  const _VoucherDetailBody({
    required this.voucher,
    required this.dateFormat,
  });

  final Voucher voucher;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _VoucherImageCarousel(
          imageAssets: voucher.imageAssets.isNotEmpty
              ? voucher.imageAssets
              : [voucher.imageAsset],
        ),
        const SizedBox(height: 12),
        _PointsBanner(
          points: voucher.points,
          label: 'Points',
        ),
        const SizedBox(height: 16),
        Text(
          voucher.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        if (voucher.subtitle.isNotEmpty)
          Text(
            voucher.subtitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        const SizedBox(height: 8),
        Text(
          'Valid until ${dateFormat.format(voucher.validUntil)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.onSurface,
                tabs: const [
                  Tab(child: Text('Description')),
                  Tab(
                    child: Text(
                      'Redemption\nRules',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Tab(child: Text('After-sales')),
                ],
              ),
              SizedBox(
                height: 180,
                child: TabBarView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(voucher.description),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(voucher.redemptionRules),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(voucher.afterSales),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VoucherImageCarousel extends StatefulWidget {
  const _VoucherImageCarousel({required this.imageAssets});

  final List<String> imageAssets;

  @override
  State<_VoucherImageCarousel> createState() => _VoucherImageCarouselState();
}

class _VoucherImageCarouselState extends State<_VoucherImageCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.imageAssets;
    return SizedBox(
      height: 400,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (value) {
                  setState(() => _index = value);
                },
                itemBuilder: (context, index) {
                  return Image.asset(
                    images[index],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  );
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_index + 1}/${images.length}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsBanner extends StatelessWidget {
  const _PointsBanner({required this.points, required this.label});

  final int points;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFF14D3A), Color(0xFFF79C2E)],
        ),
      ),
      child: Row(
        children: [
          Text(
            points.toString(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}
