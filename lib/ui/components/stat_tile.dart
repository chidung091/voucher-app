import 'package:flutter/material.dart';

/// Semantic color for stat values
enum StatColor { neutral, positive, negative }

/// Display a statistic with big number and small label
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = StatColor.neutral,
  });

  final String value;
  final String label;
  final IconData? icon;
  final StatColor color;

  Color _getValueColor(BuildContext context) {
    switch (color) {
      case StatColor.positive:
        return Theme.of(context).colorScheme.primary; // Green
      case StatColor.negative:
        return Theme.of(context).colorScheme.error; // Red
      case StatColor.neutral:
        return Theme.of(context).colorScheme.secondary; // Amber
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: _getValueColor(context).withOpacity(0.7),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _getValueColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Horizontal row of stat tiles
class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.stats,
  });

  final List<StatTile> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: stats,
    );
  }
}
