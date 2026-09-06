import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Affiche une image distante depuis :
/// - une URL publique https://...
/// - une URL Firebase Storage gs://...
///
/// Important pour l'admin : tu peux coller soit un lien public, soit un chemin
/// Firebase Storage du type gs://mon-bucket/images/affiche.png.
class RemoteImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? errorChild;
  final Widget? loadingChild;

  const RemoteImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorChild,
    this.loadingChild,
  });

  @override
  Widget build(BuildContext context) {
    final cleanSource = source.trim();
    if (cleanSource.isEmpty) return _wrap(_fallback(Icons.image_rounded));

    if (cleanSource.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: firebase_storage.FirebaseStorage.instance
            .refFromURL(cleanSource)
            .getDownloadURL(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _wrap(loadingChild ?? _loader());
          }
          final url = snap.data ?? '';
          if (url.isEmpty || snap.hasError) {
            return _wrap(errorChild ?? _fallback(Icons.broken_image_rounded));
          }
          return _network(url);
        },
      );
    }

    var url = cleanSource;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return _wrap(errorChild ?? _fallback(Icons.broken_image_rounded));
    }
    return _network(url);
  }

  Widget _network(String url) {
    return _wrap(CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => loadingChild ?? _loader(),
      errorWidget: (_, __, ___) => errorChild ?? _fallback(Icons.broken_image_rounded),
    ));
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  static Widget _loader() => Container(
        color: Colors.black.withOpacity(0.16),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      );

  static Widget _fallback(IconData icon) => Container(
        color: Colors.black.withOpacity(0.16),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.text2),
      );
}
