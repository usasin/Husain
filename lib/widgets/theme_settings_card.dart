import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';

class ThemeSettingsCard extends StatefulWidget {
  const ThemeSettingsCard({super.key});

  @override
  State<ThemeSettingsCard> createState() => _ThemeSettingsCardState();
}

class _ThemeSettingsCardState extends State<ThemeSettingsCard> {
  Timer? _noticeTimer;
  bool _showApplyingNotice = false;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  Future<void> _applyTheme(
    AppThemeController controller,
    ThemeMode next,
  ) async {
    if (next == controller.mode) return;

    _noticeTimer?.cancel();
    setState(() => _showApplyingNotice = true);

    // Aucun SnackBar/Navigator ici : le changement de thème peut reconstruire
    // l'écran courant. L'indicateur reste local à cette carte et ne cherche
    // donc aucun ancêtre avec un BuildContext en transition.
    await controller.setMode(next);
    if (!mounted) return;

    _noticeTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showApplyingNotice = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppThemeController>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.overlayBase.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                controller.mode == ThemeMode.light
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: AppColors.limeDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Apparence', 'Appearance'),
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.tr(
                        'Choisis clair ou sombre',
                        'Choose light or dark',
                      ),
                      style: TextStyle(color: AppColors.text2, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode_rounded, size: 16),
                label: Text(context.tr('Clair', 'Light')),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode_rounded, size: 16),
                label: Text(context.tr('Sombre', 'Dark')),
              ),
            ],
            selected: {controller.mode},
            onSelectionChanged: (value) {
              _applyTheme(controller, value.first);
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _showApplyingNotice
                ? Padding(
                    key: const ValueKey('theme-applying'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.lime.withOpacity(.28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sync_rounded,
                                size: 17,
                                color: AppColors.limeDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr(
                                    'Application du thème…',
                                    'Applying theme…',
                                  ),
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 7),
                          Text(
                            context.tr(
                              'Le changement peut prendre quelques instants avant d’être visible dans toute l’application.',
                              'The change may take a few moments before it is visible throughout the app.',
                            ),
                            style: TextStyle(
                              color: AppColors.text2,
                              fontSize: 10.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('theme-idle')),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppColors.grey,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.tr(
                    'Le thème se met à jour dans toute l’application. Certains éléments peuvent prendre quelques instants.',
                    'The theme updates across the whole app. Some elements may take a few moments.',
                  ),
                  style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
