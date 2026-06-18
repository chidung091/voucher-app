import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/responsive.dart';

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.children,
    this.maxWidth = 1120,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.physics,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding =
        padding ?? ResponsiveBreakpoints.pagePadding(context);

    return ListView(
      padding: resolvedPadding.add(
        EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      ),
      physics: physics,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? ResponsiveBreakpoints.pagePadding(context),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 320,
    this.maxColumns = 3,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    super.key,
    required this.start,
    required this.end,
    this.breakpoint = 900,
    this.spacing = AppSpacing.lg,
    this.startFlex = 1,
    this.endFlex = 1,
  });

  final Widget start;
  final Widget end;
  final double breakpoint;
  final double spacing;
  final int startFlex;
  final int endFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              start,
              SizedBox(height: spacing),
              end,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: startFlex, child: start),
            SizedBox(width: spacing),
            Expanded(flex: endFlex, child: end),
          ],
        );
      },
    );
  }
}
