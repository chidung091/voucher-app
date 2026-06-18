import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../core/app_theme.dart';
import '../../state/providers.dart';
import '../../widgets/responsive_page.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);

    return ResponsivePage(
      maxWidth: 860,
      children: [
        Text(
          localizations.settingsTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.themeTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ThemeOption(
                  label: localizations.themeSystem,
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    ref.read(themeModeProvider.notifier).state = mode;
                  },
                ),
                _ThemeOption(
                  label: localizations.themeLight,
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    ref.read(themeModeProvider.notifier).state = mode;
                  },
                ),
                _ThemeOption(
                  label: localizations.themeDark,
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (mode) {
                    ref.read(themeModeProvider.notifier).state = mode;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ResponsiveGrid(
          minItemWidth: 320,
          maxColumns: 2,
          children: [
            Card(
              child: ListTile(
                title: Text(localizations.languageTitle),
                subtitle: Text(localizations.english),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
            Card(
              child: ListTile(
                title: Text(localizations.apiEnvironmentTitle),
                subtitle: Text(localizations.apiEnvironmentProduction),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: (mode) {
        if (mode != null) {
          onChanged(mode);
        }
      },
    );
  }
}
