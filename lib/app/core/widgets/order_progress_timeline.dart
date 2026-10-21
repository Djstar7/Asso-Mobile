import 'package:flutter/material.dart';

import '../../data/models/order_progress.dart';

class OrderProgressTimeline extends StatelessWidget {
  final OrderProgress progress;

  const OrderProgressTimeline({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final stages = progress.isCancelled ? const ['cancelled'] : progress.steps;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, stage) in stages.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  progress.isCancelled
                      ? Icons.cancel_outlined
                      : index < progress.index
                      ? Icons.check_circle
                      : index == progress.index
                      ? progress.icon
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: progress.isCancelled
                      ? theme.colorScheme.error
                      : index <= progress.index
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    progress.labelForStep(stage),
                    style: TextStyle(
                      fontWeight: stage == progress.stage
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: !progress.isCancelled && index > progress.index
                          ? theme.disabledColor
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
