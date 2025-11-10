import 'package:flutter/material.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/components/card.dart';
import '../../../design system/components/list_tile.dart';

class MiniCalendar extends StatelessWidget {
  final Map<DateTime, List<Map<String, dynamic>>> items;
  const MiniCalendar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final dates = items.keys.toList()..sort();
    if (dates.isEmpty) {
      return AppCard(
        content: AppCardContent(
          child: Padding(
            padding: EdgeInsets.all((Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0) * 2),
            child: const Text('Nessun evento imminente'),
          ),
        ),
      );
    }
    return AppCard(
      content: AppCardContent(
        child: Padding(
          padding: EdgeInsets.all(Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: dates.length,
            itemBuilder: (_, i) {
              final d = dates[i];
              final it = items[d]!;
              return ExpansionTile(
                title: Text('${_fmt(d)} — ${it.length} evento/i'),
                children: [
                  for (final e in it)
                    AppListTile(
                      dense: true,
                      leading: Icon(e['type'] == 'hearing'
                          ? AppIcons.gavel
                          : AppIcons.checkCircle),
                      title: Text(e['type'] == 'hearing'
                          ? (e['subject'] ?? 'Udienza')
                          : (e['title'] ?? 'Task')),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
