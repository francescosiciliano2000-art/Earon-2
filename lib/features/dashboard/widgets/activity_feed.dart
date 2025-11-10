import 'package:flutter/material.dart';
import '../../../design system/icons/app_icons.dart';
import '../../../design system/theme/themes.dart';
import '../../../design system/components/card.dart';
import '../../../design system/components/list_tile.dart';

class ActivityFeed extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> matters;
  const ActivityFeed(
      {super.key, required this.documents, required this.matters});

  @override
  Widget build(BuildContext context) {
    final double unit = Theme.of(context).extension<DefaultTokens>()?.spacingUnit ?? 8.0;
    return AppCard(
      header: const AppCardHeader(
        title: AppCardTitle(Text('Attività recente')),
      ),
      content: AppCardContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (documents.isEmpty && matters.isEmpty)
              Padding(
                padding: EdgeInsets.all(unit),
                child: const Text('Nessuna attività recente'),
              ),
            if (documents.isNotEmpty) ...[
              const AppListTile(title: Text('Documenti')),
              SizedBox(height: unit),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final d = documents[index];
                  return AppListTile(
                    dense: true,
                    leading: const Icon(AppIcons.insertDriveFile),
                    title: Text(d['filename'] ?? 'Documento'),
                    subtitle: Text('${d['created_at'] ?? ''}'),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: unit,
                      vertical: unit / 2,
                    ),
                  );
                },
                separatorBuilder: (context, index) => SizedBox(height: unit / 2),
                itemCount: documents.length > 5 ? 5 : documents.length,
              ),
            ],
            if (matters.isNotEmpty) ...[
              const AppListTile(title: Text('Pratiche')),
              for (final m in matters.take(5))
                AppListTile(
                  dense: true,
                  leading: const Icon(AppIcons.folder),
                  title: Text(m['title'] ?? 'Pratica'),
                  subtitle:
                      Text('${m['code'] ?? ''}  •  ${m['created_at'] ?? ''}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
