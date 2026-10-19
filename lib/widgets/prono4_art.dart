import 'package:flutter/material.dart';

/// Images 2026 officielles PRONO4. Purement visuel, sans réseau ni Firebase.
class Prono4Art extends StatelessWidget {
  const Prono4Art({
    super.key,
    required this.name,
    this.size = 32,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    const supported = {'accueil', 'etoile', 'duel', 'classement', 'equipe', 'profile'};
    if (!supported.contains(name)) return SizedBox(width: size, height: size);
    return Image.asset(
      'assets/ui/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(Icons.sports_soccer_rounded, size: size),
    );
  }
}
