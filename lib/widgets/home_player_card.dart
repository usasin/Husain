import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_locale.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'reputation_badge.dart';
import 'team_badge.dart';
import 'avatar_display.dart';

class HomePlayerCard extends StatelessWidget {
  final AppProvider provider;
  final VoidCallback onCreateTeam;
  final VoidCallback onJoinTeam;
  final VoidCallback onTeamTap;
  final VoidCallback onRankingTap;
  final VoidCallback onProfileTap;
  const HomePlayerCard({
    super.key,
    required this.provider,
    required this.onCreateTeam,
    required this.onJoinTeam,
    required this.onTeamTap,
    required this.onRankingTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = provider.currentUser;
    if (user == null) return const SizedBox.shrink();
    final team = provider.myTeam;
    final badge = provider.getAutoReputationBadge(user.id);
    final asset = reputationBadgeAsset(context, badge);
    final knowledge = provider.getUserKnowledgeScore(user.id);
    final points = team == null
        ? provider.getUserPoints(user.id)
        : provider.getTeamPoints(team.id).round();
    final pointsAvailable = team == null
        ? provider.hasUserRecordedStats(user.id)
        : provider.hasTeamRecordedStats(team.id);
    final statsAvailable = provider.hasUserRecordedStats(user.id);
    var rank = 0;
    if (team != null && provider.rankingDataLoaded) {
      final index = provider.getTeamRanking().indexWhere(
            (row) => row['team'].id == team.id,
          );
      if (index >= 0) rank = index + 1;
    }
    final next = switch (badge.toUpperCase()) {
      'FOOTIX' => 40,
      'AMATEUR' => 55,
      'CONNAISSEUR' => 70,
      'CONFIRMÉ' || 'CONFIRME' => 85,
      'EXPERT' => knowledge,
      _ => 55,
    };
    final remaining = (next - knowledge).clamp(0, 100);
    Widget teamImage() {
      final fallback = TeamBadge(team: team!, size: 40);
      if (team.imageB64.isEmpty) return fallback;
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(team.imageB64),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('Bonjour ${user.name} 👋', 'Hi ${user.name} 👋'),
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(24),
              child: Semantics(
                button: true,
                label: context.tr('Mon profil', 'My profile'),
                child: AvatarBubble(
                  avatar: user.avatar,
                  userId: user.id,
                  size: 44,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.lime.withValues(alpha: .35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.lime.withValues(alpha: .13), AppColors.bg2],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: asset == null
                        ? const Icon(
                            Icons.shield_rounded,
                            color: AppColors.lime,
                            size: 52,
                          )
                        : Image.asset(asset, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: team == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: onCreateTeam,
                                icon: const Icon(
                                  Icons.group_add_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.tr(
                                    'Créer une équipe',
                                    'Create a team',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: onJoinTeam,
                                child: Text(
                                  context.tr(
                                    'Rejoindre avec un code',
                                    'Join with a code',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: onTeamTap,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  teamImage(),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceGrotesk(
                                            color: AppColors.text,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${team.memberIds.length}/4 ${context.tr('membres', 'members')}',
                                          style: TextStyle(
                                            color: AppColors.text2,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      context,
                      Icons.emoji_events_rounded,
                      rank == 0 ? '—' : '#$rank',
                      context.tr('Classement', 'Ranking'),
                      onRankingTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(
                      context,
                      Icons.trending_up_rounded,
                      pointsAvailable ? '$points' : '…',
                      team == null
                          ? context.tr('Mes points', 'My points')
                          : context.tr('Points équipe', 'Team points'),
                      onRankingTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Progression', 'Progress'),
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    statsAvailable ? '$knowledge/100' : '…/100',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value:
                      statsAvailable ? (knowledge / 100).clamp(0.0, 1.0) : null,
                  minHeight: 7,
                  color: AppColors.lime,
                  backgroundColor: AppColors.bg3,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  !statsAvailable
                      ? context.tr('Chargement de ta progression…',
                          'Loading your progress…')
                      : remaining == 0
                          ? context.tr(
                              'Niveau maximum atteint 👑',
                              'Maximum level reached 👑',
                            )
                          : context.tr(
                              'Encore $remaining points pour le niveau suivant !',
                              '$remaining points to the next level!',
                            ),
                  style: TextStyle(color: AppColors.text2, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    VoidCallback onTap,
  ) =>
      Material(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.lime, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 2,
                        style: TextStyle(color: AppColors.text2, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
