import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Custom dropdown that opens a modal bottom sheet for selection
class DropdownField<T> extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.value,
    this.hint,
    this.itemBuilder,
    this.enabled = true,
    this.prefixIcon,
  });

  final String label;
  final List<T> items;
  final T? value;
  final String? hint;
  final void Function(T?) onSelected;
  final Widget Function(T)? itemBuilder;
  final bool enabled;
  final Widget? prefixIcon;

  String _getDisplayText(T? item) {
    if (item == null) return hint ?? 'Select...';
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: enabled ? () => _showBottomSheet(context) : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: enabled
                  ? theme.inputDecorationTheme.fillColor
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: enabled
                    ? colorScheme.outline.withOpacity(0.2)
                    : colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    _getDisplayText(value),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: value != null
                          ? theme.textTheme.bodyLarge?.color
                          : theme.textTheme.bodyLarge?.color?.withOpacity(0.38),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: enabled
                      ? theme.textTheme.bodyLarge?.color?.withOpacity(0.6)
                      : theme.textTheme.bodyLarge?.color?.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item == value;

                  return ListTile(
                    title: itemBuilder != null
                        ? itemBuilder!(item)
                        : Text(_getDisplayText(item)),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      onSelected(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown item wrapper for simple value/label pairs
class DropdownItem<T> {
  const DropdownItem({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;

  @override
  String toString() => label;
}
