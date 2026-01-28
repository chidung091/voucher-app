import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class CustomDialog extends StatelessWidget {
  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      content: content,
      actions: actions,
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
    );
  }
}
