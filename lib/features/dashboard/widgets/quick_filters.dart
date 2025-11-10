import 'package:flutter/material.dart';
// import 'package:gestionale_desktop/ui/components/chips/app_chips.dart'; // legacy, sostituito con i Material Chips
import '../../../design system/theme/themes.dart';

class QuickFilters extends StatelessWidget {
  final bool onlyMine;
  final int rangeDays;
  final ValueChanged<bool> onOnlyMine;
  final ValueChanged<int> onRangeDays;
  const QuickFilters({
    super.key,
    required this.onlyMine,
    required this.rangeDays,
    required this.onOnlyMine,
    required this.onRangeDays,
  });

  @override
  Widget build(BuildContext context) {
    final double unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return Wrap(
      spacing: unit,
      runSpacing: unit,
      children: [
        FilterChip(
          label: const Text('Solo mie'),
          selected: onlyMine,
          onSelected: (v) => onOnlyMine(v),
        ),
        ChoiceChip(
          label: const Text('7 giorni'),
          selected: rangeDays == 7,
          onSelected: (_) => onRangeDays(7),
        ),
        ChoiceChip(
          label: const Text('30 giorni'),
          selected: rangeDays == 30,
          onSelected: (_) => onRangeDays(30),
        ),
      ],
    );
  }
}
