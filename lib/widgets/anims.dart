import 'package:flutter/material.dart';

/// Entrée animée : fondu + léger glissement vers le haut.
/// `order` décale légèrement l'arrivée (effet cascade).
class Appear extends StatelessWidget {
  final Widget child;
  final int order;
  final double offsetY;
  const Appear({
    super.key,
    required this.child,
    this.order = 0,
    this.offsetY = 18,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + order.clamp(0, 6) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offsetY),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Pulsation répétée (effet « vivant » / champion).
class Pulse extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double max;
  const Pulse({
    super.key,
    required this.child,
    this.enabled = true,
    this.max = 1.08,
  });

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: widget.max)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Apparition « pop » avec rebond, pour les célébrations (prono gagné…).
class Pop extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const Pop({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (context, t, c) => Transform.scale(
        scale: t.clamp(0.0, 1.25),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: c),
      ),
      child: child,
    );
  }
}
