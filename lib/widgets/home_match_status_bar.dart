import 'package:flutter/material.dart';
import '../data/home_match_filter.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

class HomeMatchStatusBar extends StatelessWidget {
  final HomeMatchStatus value;
  final ValueChanged<HomeMatchStatus> onChanged;
  const HomeMatchStatusBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      HomeMatchStatus.upcoming: context.tr('À venir', 'Upcoming'),
      HomeMatchStatus.live: context.tr('En direct', 'Live'),
      HomeMatchStatus.finished: context.tr('Terminés', 'Finished'),
    };
    return Container(
      key: const Key('home-three-status-frame'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: AppColors.lime.withValues(alpha: .55), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in labels.entries) ...[
                if (entry.key != HomeMatchStatus.upcoming)
                  Container(
                    width: 1,
                    color: AppColors.overlayBase.withValues(alpha: .10),
                  ),
                Expanded(
                  child: Material(
                    color: value == entry.key
                        ? AppColors.lime
                        : Colors.transparent,
                    child: Semantics(
                      selected: value == entry.key,
                      child: TextButton(
                        onPressed: () => onChanged(entry.key),
                        style: TextButton.styleFrom(
                          foregroundColor: value == entry.key
                              ? const Color(0xFF101211)
                              : AppColors.text2,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
