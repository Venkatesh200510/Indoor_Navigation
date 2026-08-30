import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Full-screen gradient backdrop with two soft glowing blobs, used behind
/// every screen so the app feels less flat than a solid color background.
class GradientBackdrop extends StatelessWidget {
  final Widget child;
  const GradientBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _glow(AppColors.violet.withValues(alpha: 0.28), 220),
        ),
        Positioned(
          bottom: -100,
          left: -70,
          child: _glow(AppColors.mint.withValues(alpha: 0.16), 260),
        ),
        child,
      ],
    );
  }

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

/// Frosted "glass" container — a blurred, translucent panel with a subtle
/// border. Used in place of the old flat solid-color cards.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Gradient? borderGradient;
  final Color tint;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 18,
    this.borderGradient,
    this.tint = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient,
      ),
      padding: borderGradient != null ? const EdgeInsets.all(1.4) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - (borderGradient != null ? 1.4 : 0)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(radius - (borderGradient != null ? 1.4 : 0)),
              border: borderGradient == null
                  ? Border.all(color: AppColors.outline)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Wraps a tappable child with a light scale-down animation + haptic tick,
/// so every interactive element in the app has the same tactile feel.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double downScale;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.downScale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.downScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides a child in from below. Give items in a list an
/// increasing [index] to get a staggered "cascade" entrance.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 45),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 340 + (index * 40).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A small animated gradient dot used as a "live" indicator.
class PulseDot extends StatefulWidget {
  final Color color;
  const PulseDot({super.key, this.color = AppColors.mint});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.4 + _c.value * 0.6),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * _c.value),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
