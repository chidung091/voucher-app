import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          localizations.dashboardTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          localizations.dashboardSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 840;
            return GridView.count(
              shrinkWrap: true,
              crossAxisCount: isWide ? 3 : 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.25,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MetricCard(
                  title: localizations.activeVouchers,
                  value: '132',
                  trend: '+6.8%',
                  icon: Icons.card_giftcard_outlined,
                ),
                _MetricCard(
                  title: localizations.redemptionsToday,
                  value: '48',
                  trend: '+12%',
                  icon: Icons.qr_code_scanner_outlined,
                ),
                _MetricCard(
                  title: localizations.spendSaved,
                  value: '\$2.4k',
                  trend: '+3.1%',
                  icon: Icons.savings_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: localizations.latestActivity,
          actionLabel: localizations.viewAll,
          onAction: () {},
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _ActivityTile(
                title: localizations.activityVoucherRedeemed,
                subtitle: localizations.activityTimeStore,
                icon: Icons.storefront_outlined,
              ),
              const Divider(height: 1),
              _ActivityTile(
                title: localizations.activityCampaignStarted,
                subtitle: localizations.activityTimeOnline,
                icon: Icons.rocket_launch_outlined,
              ),
              const Divider(height: 1),
              _ActivityTile(
                title: localizations.activitySegmentUploaded,
                subtitle: localizations.activityTimeCrm,
                icon: Icons.group_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: localizations.highlightsTitle,
          actionLabel: localizations.createReport,
          onAction: () {},
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.highlightTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.highlightDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(localizations.reviewInsights),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
  });

  final String title;
  final String value;
  final String trend;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
