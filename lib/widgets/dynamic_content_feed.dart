import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'remote_image.dart';

/// Cartes dynamiques pilotées depuis l'admin.
/// Collection Firestore : dynamicContents/{id}
class DynamicContentFeed extends StatelessWidget {
  final String placement;
  final EdgeInsets margin;
  final int? limit;

  const DynamicContentFeed({
    super.key,
    required this.placement,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('dynamicContents').snapshots(),
      builder: (context, snap) {
        final now = DateTime.now();
        final cards = (snap.data?.docs ?? [])
            .map((doc) => _DynamicContentCardData.fromDoc(doc))
            .where((card) => card.isVisibleAt(now, placement))
            .toList()
          ..sort((a, b) {
            final order = a.order.compareTo(b.order);
            if (order != 0) return order;
            return b.updatedAt.compareTo(a.updatedAt);
          });

        final visible = limit == null ? cards : cards.take(limit!).toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        if (visible.length == 1) {
          return Padding(
            padding: margin,
            child: _DynamicContentCard(card: visible.first),
          );
        }

        return Padding(
          padding: margin,
          child: SizedBox(
            height: 300,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.94),
              itemCount: visible.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(right: index == visible.length - 1 ? 0 : 10),
                child: _DynamicContentCard(card: visible[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DynamicContentCardData {
  final String id;
  final bool enabled;
  final String placement;
  final String style;
  final String title;
  final String message;
  final String imageUrl;
  final String buttonText;
  final String buttonUrl;
  final String backgroundColor;
  final String textColor;
  final int order;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime updatedAt;

  _DynamicContentCardData({
    required this.id,
    required this.enabled,
    required this.placement,
    required this.style,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.buttonText,
    required this.buttonUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.order,
    required this.startAt,
    required this.endAt,
    required this.updatedAt,
  });

  factory _DynamicContentCardData.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _DynamicContentCardData(
      id: doc.id,
      enabled: data['enabled'] == true,
      placement: (data['placement'] ?? 'home_top').toString(),
      style: (data['style'] ?? 'hero').toString(),
      title: (data['title'] ?? '').toString().trim(),
      message: (data['message'] ?? '').toString().trim(),
      imageUrl: (data['imageUrl'] ?? '').toString().trim(),
      buttonText: (data['buttonText'] ?? '').toString().trim(),
      buttonUrl: (data['buttonUrl'] ?? '').toString().trim(),
      backgroundColor: (data['backgroundColor'] ?? '#172B43').toString(),
      textColor: (data['textColor'] ?? '#F8FBFF').toString(),
      order: _toInt(data['order'], 100),
      startAt: _toDate(data['startAt']),
      endAt: _toDate(data['endAt']),
      updatedAt: _toDate(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool isVisibleAt(DateTime now, String wantedPlacement) {
    if (!enabled) return false;
    if (placement != wantedPlacement) return false;
    if (title.isEmpty && message.isEmpty && imageUrl.isEmpty) return false;
    if (startAt != null && now.isBefore(startAt!)) return false;
    if (endAt != null && now.isAfter(endAt!)) return false;
    return true;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _DynamicContentCard extends StatefulWidget {
  final _DynamicContentCardData card;
  const _DynamicContentCard({required this.card});

  @override
  State<_DynamicContentCard> createState() => _DynamicContentCardState();
}

class _DynamicContentCardState extends State<_DynamicContentCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final bg = _parseHex(card.backgroundColor, AppColors.bg2);
    final fg = _parseHex(card.textColor, AppColors.text);
    final uri = _safeUri(card.buttonUrl);
    final compact = card.style == 'compact';
    final alert = card.style == 'alert';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2);
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (alert ? AppColors.canadaRed : AppColors.gold)
                  .withOpacity(alert ? 0.55 : 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.20),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
              if (alert)
                BoxShadow(
                  color: AppColors.canadaRed.withOpacity(0.14 + wave * 0.12),
                  blurRadius: 22 + wave * 10,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: uri == null ? null : () => launchUrl(uri, mode: LaunchMode.externalApplication),
              child: compact ? _compact(card, fg, uri) : _hero(card, fg, uri),
            ),
          ),
        );
      },
    );
  }

  Widget _hero(_DynamicContentCardData card, Color fg, Uri? uri) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.imageUrl.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: RemoteImage(source: card.imageUrl),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: _textBlock(card, fg, uri),
        ),
      ],
    );
  }

  Widget _compact(_DynamicContentCardData card, Color fg, Uri? uri) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (card.imageUrl.isNotEmpty) ...[
            SizedBox(
              width: 82,
              height: 82,
              child: RemoteImage(
                source: card.imageUrl,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: _textBlock(card, fg, uri, compact: true)),
        ],
      ),
    );
  }

  Widget _textBlock(
    _DynamicContentCardData card,
    Color fg,
    Uri? uri, {
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withOpacity(0.42)),
              ),
              alignment: Alignment.center,
              child: Icon(
                card.style == 'alert'
                    ? Icons.flash_on_rounded
                    : Icons.auto_awesome_rounded,
                color: AppColors.gold,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (card.title.isNotEmpty)
                    Text(
                      card.title,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlowCondensed(
                        color: fg,
                        fontSize: compact ? 18 : 21,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  if (card.message.isNotEmpty) ...[
                    if (card.title.isNotEmpty) const SizedBox(height: 5),
                    Text(
                      card.message,
                      maxLines: compact ? 3 : 6,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.barlow(
                        color: fg.withOpacity(0.92),
                        fontSize: 14,
                        height: 1.32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (uri != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.buttonText.isEmpty ? 'OUVRIR' : card.buttonText,
                    style: GoogleFonts.barlowCondensed(
                      color: AppColors.bg0,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.bg0),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Uri? _safeUri(String raw) {
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

  static Color _parseHex(String raw, Color fallback) {
    var hex = raw.trim().toUpperCase().replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? fallback : Color(value);
  }
}
