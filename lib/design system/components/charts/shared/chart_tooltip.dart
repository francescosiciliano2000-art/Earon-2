import 'package:flutter/material.dart';

class AppBarTooltip extends StatelessWidget {
  const AppBarTooltip(
      {super.key, required this.items, required this.title, this.width});
  final List<(Color color, String label, String value)> items;
  final String title;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      elevation: 2,
      color: t.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: width ?? 160),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: DefaultTextStyle(
            style: t.textTheme.bodySmall!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.textTheme.labelMedium!
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...items.map((e) {
                  final (c, label, value) = e;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                      Text(value,
                          style: t.textTheme.labelSmall!.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
