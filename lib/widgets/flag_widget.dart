import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FlagWidget extends StatelessWidget {
  final String flagCode;
  final double size;
  final String fallbackEmoji;

  const FlagWidget({
    super.key,
    required this.flagCode,
    this.size = 36,
    this.fallbackEmoji = '🌍',
  });

  @override
  Widget build(BuildContext context) {
    if (flagCode.isEmpty) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.9));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CachedNetworkImage(
        imageUrl: 'https://flagcdn.com/w80/${flagCode.toLowerCase()}.png',
        width: size,
        height: size * 0.65,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size * 0.65,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        errorWidget: (_, __, ___) => Text(
          fallbackEmoji,
          style: TextStyle(fontSize: size * 0.8),
        ),
      ),
    );
  }
}
