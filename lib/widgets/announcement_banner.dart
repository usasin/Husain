import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'remote_image.dart';

/// Bandeau d'annonce piloté depuis Firestore : system/appConfig.
///
/// Champs acceptés :
/// - announcementEnabled: bool
/// - announcementTitle: string
/// - announcementMessage: string
/// - announcementButtonText: string
/// - announcementUrl: string
/// - announcementImageUrl: string
/// - announcementTextColor: string HEX ex #FFFFFF
/// - announcementBackgroundColor: string HEX ex #172B43
/// - announcementAnimation: none | glow | marquee | pulse
///
/// Le champ historique `announcement` reste supporté pour les anciennes annonces.
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('system')
          .doc('appConfig')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};

        final enabled = data['announcementEnabled'] != false;
        final title = (data['announcementTitle'] ?? '').toString().trim();
        final message = ((data['announcementMessage'] ?? data['announcement']) ?? '')
            .toString()
            .trim();
        final imageUrl =
            (data['announcementImageUrl'] ?? '').toString().trim();
        final linkUrl = (data['announcementUrl'] ?? '').toString().trim();
        final buttonText = (data['announcementButtonText'] ?? '')
            .toString()
            .trim();
        final animation = _cleanAnimation(
          (data['announcementAnimation'] ?? 'none').toString(),
        );

        if (!enabled ||
            (title.isEmpty &&
                message.isEmpty &&
                imageUrl.isEmpty &&
                linkUrl.isEmpty)) {
          return const SizedBox.shrink();
        }

        final bgColor = _parseHexColor(
          (data['announcementBackgroundColor'] ?? '').toString(),
          AppColors.bg2,
        );
        final textColor = _parseHexColor(
          (data['announcementTextColor'] ?? '').toString(),
          AppColors.text,
        );
        final imageSource = _safeImageSource(imageUrl);
        final linkUri = _safeLinkUri(linkUrl);

        return _AnimatedAnnouncementCard(
          title: title,
          message: message,
          imageSource: imageSource,
          linkUri: linkUri,
          buttonText: buttonText,
          bgColor: bgColor,
          textColor: textColor,
          animation: animation,
        );
      },
    );
  }

  static String _cleanAnimation(String raw) {
    final value = raw.trim().toLowerCase();
    const allowed = {'none', 'glow', 'marquee', 'pulse'};
    return allowed.contains(value) ? value : 'none';
  }

  static String? _safeImageSource(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('gs://')) return value;
    var url = value;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return url;
  }

  static Uri? _safeLinkUri(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  static Color _parseHexColor(String raw, Color fallback) {
    var hex = raw.trim().toUpperCase().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return fallback;
    return Color(value);
  }
}

class _AnimatedAnnouncementCard extends StatefulWidget {
  final String title;
  final String message;
  final String? imageSource;
  final Uri? linkUri;
  final String buttonText;
  final Color bgColor;
  final Color textColor;
  final String animation;

  const _AnimatedAnnouncementCard({
    required this.title,
    required this.message,
    required this.imageSource,
    required this.linkUri,
    required this.buttonText,
    required this.bgColor,
    required this.textColor,
    required this.animation,
  });

  @override
  State<_AnimatedAnnouncementCard> createState() =>
      _AnimatedAnnouncementCardState();
}

class _AnimatedAnnouncementCardState extends State<_AnimatedAnnouncementCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
        final glowActive = widget.animation == 'glow';
        final pulseActive = widget.animation == 'pulse';
        final scale = pulseActive ? 1.0 + (wave * 0.012) : 1.0;
        final goldGlow = glowActive ? 0.22 + (wave * 0.28) : 0.18;

        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: widget.bgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.gold.withOpacity(glowActive ? 0.55 : 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
                if (glowActive)
                  BoxShadow(
                    color: AppColors.gold.withOpacity(goldGlow),
                    blurRadius: 22 + (wave * 12),
                    spreadRadius: 1 + (wave * 2),
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _content(context),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.imageSource != null)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: RemoteImage(source: widget.imageSource!),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.gold.withOpacity(0.45),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.campaign_rounded,
                      size: 18,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title.isNotEmpty)
                          Text(
                            widget.title,
                            style: GoogleFonts.barlowCondensed(
                              color: widget.textColor,
                              fontSize: 19,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        if (widget.message.isNotEmpty) ...[
                          if (widget.title.isNotEmpty)
                            const SizedBox(height: 5),
                          if (widget.animation == 'marquee')
                            _MarqueeAnnouncementText(
                              text: widget.message,
                              color: widget.textColor.withOpacity(0.92),
                            )
                          else
                            Text(
                              widget.message,
                              style: GoogleFonts.barlow(
                                color: widget.textColor.withOpacity(0.92),
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.linkUri != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(context, widget.linkUri!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.bg0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(
                      widget.buttonText.isEmpty
                          ? 'OUVRIR LE LIEN'
                          : widget.buttonText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _openLink(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien impossible à ouvrir.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien impossible à ouvrir.')),
        );
      }
    }
  }
}

class _MarqueeAnnouncementText extends StatefulWidget {
  final String text;
  final Color color;

  const _MarqueeAnnouncementText({
    required this.text,
    required this.color,
  });

  @override
  State<_MarqueeAnnouncementText> createState() =>
      _MarqueeAnnouncementTextState();
}

class _MarqueeAnnouncementTextState extends State<_MarqueeAnnouncementText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.barlow(
      color: widget.color,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w700,
    );

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout();

          if (painter.width <= constraints.maxWidth) {
            return Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
          }

          final totalDistance = constraints.maxWidth + painter.width + 40;

          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final dx = constraints.maxWidth -
                    (_controller.value * totalDistance);
                return Stack(
                  children: [
                    Positioned(
                      left: dx,
                      top: 0,
                      child: Text(
                        widget.text,
                        maxLines: 1,
                        softWrap: false,
                        style: style,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
