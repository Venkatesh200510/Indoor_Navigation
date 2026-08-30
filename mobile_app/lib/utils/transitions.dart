import 'package:flutter/material.dart';

/// Pushes [page] with a fade + gentle slide-up transition instead of the
/// default platform transition, so moving between screens feels smoother.
Future<T?> pushFancy<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
