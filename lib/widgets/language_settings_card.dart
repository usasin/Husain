import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

class LanguageSettingsCard extends StatelessWidget {
  const LanguageSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppLocaleController>();
    final current = controller.locale?.languageCode ?? 'system';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(children: [
        const Icon(Icons.language_rounded, color: AppColors.lime),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Langue', 'Language'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          Text(context.tr('Français / English / système', 'French / English / system'), style: const TextStyle(color: AppColors.text2, fontSize: 11)),
        ])),
        DropdownButton<String>(
          value: current,
          dropdownColor: AppColors.bg2,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'system', child: Text('Auto')),
            DropdownMenuItem(value: 'fr', child: Text('FR')),
            DropdownMenuItem(value: 'en', child: Text('EN')),
          ],
          onChanged: (v) => controller.setLanguage(v == 'system' ? null : v),
        ),
      ]),
    );
  }
}
