import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_locale.dart';

/// Secondary app information; attribution stays out of the game feed.
class SourcesLicensesTile extends StatelessWidget {
  const SourcesLicensesTile({super.key, this.openLink});

  final Future<bool> Function(Uri)? openLink;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await (openLink?.call(uri) ??
        launchUrl(uri, mode: LaunchMode.externalApplication));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('Lien indisponible pour le moment.',
            'Link unavailable at the moment.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline_rounded, size: 20),
        title: Text(context.tr('Sources et licences', 'Sources and licenses')),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(context.tr('Sources et licences', 'Sources and licenses')),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.tr(
                  'Les scores et le classement Europa utilisent des données '
                  'OpenLigaDB, disponibles sous licence ODbL.',
                  'Europa scores and standings use OpenLigaDB data, '
                  'available under the ODbL license.',
                )),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _open(dialogContext, 'https://www.openligadb.de/'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('OpenLigaDB'),
                ),
                TextButton.icon(
                  onPressed: () => _open(dialogContext,
                      'https://opendatacommons.org/licenses/odbl/1-0/'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(context.tr('Licence ODbL', 'ODbL license')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.tr('Fermer', 'Close')),
              ),
            ],
          ),
        ),
      );
}
