import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_controller.dart';
import '../widgets/admob_banner.dart';
import '../l10n/app_locale.dart';
import 'competition_home_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'team_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // MainShell écoute le thème, mais conserve les mêmes Element/State.
    // On crée de nouvelles instances de widgets (sans clés de remplacement) :
    // Flutter les met à jour et les reconstruit sans désactiver leur contexte.
    context.watch<AppThemeController>();
    final hasTeam = context.select<AppProvider, bool>((p) => p.myTeam != null);
    final screens = <Widget>[
      CompetitionHomeScreen(
        onRankingTap: () => _go(1),
        onTeamTap: () => _go(2),
        onProfileTap: () => _go(3),
      ),
      LeaderboardScreen(),
      TeamScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      extendBody: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: IndexedStack(
            index: _index,
            children: List.generate(
              screens.length,
              (i) => TickerMode(
                enabled: i == _index,
                child: RepaintBoundary(child: screens[i]),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdMobBanner(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Prono4BottomNav(
                currentIndex: _index,
                hasTeam: hasTeam,
                onTap: _go,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _go(int i) {
    // BUILD80: each ranking screen owns its single load in initState. Keeping
    // navigation pure avoids duplicate requests when a tab is selected.
    setState(() => _index = i);
  }
}

class Prono4BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool hasTeam;
  final ValueChanged<int> onTap;

  const Prono4BottomNav({
    super.key,
    required this.currentIndex,
    required this.hasTeam,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_NavData>[
      _NavData(Icons.home_rounded, context.tr('Accueil', 'Home')),
      _NavData(Icons.leaderboard_rounded, context.tr('Classement', 'Ranking')),
      _NavData(
        hasTeam ? Icons.groups_2_rounded : Icons.group_add_rounded,
        context.tr('Équipe', 'Team'),
      ),
      _NavData(Icons.person_rounded, context.tr('Profil', 'Profile')),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bg1.withOpacity(.98),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.overlayBase.withOpacity(.07)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final active = i == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.lime.withOpacity(.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 21,
                        color: active ? AppColors.lime : AppColors.grey,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? AppColors.lime : AppColors.grey,
                          fontSize: 9,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavData {
  final IconData icon;
  final String label;
  const _NavData(this.icon, this.label);
}
