// lib/components/avatar.dart
import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import '../theme/typography.dart';

enum AppAvatarSize { sm, md, lg }

/// AppAvatar — porting di `Avatar` shadcn/ui
/// - h/w: sm=24, md=32, lg=40 (default lg per parità h-10)
/// - rounded-full, border opzionale (token border), ring opzionale (token ring)
/// - Fallback con iniziali se l'immagine non è disponibile
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.size = AppAvatarSize.lg,
    this.imageUrl,
    this.imageProvider,
    this.name,
    this.showBorder = true,
    this.showRing = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final AppAvatarSize size;
  final String? imageUrl;
  final ImageProvider? imageProvider;
  final String? name;
  final bool showBorder;
  final bool showRing;
  final Color? backgroundColor;
  final Color? foregroundColor;

  double get _side => switch (size) {
        AppAvatarSize.sm => 24,
        AppAvatarSize.md => 32,
        AppAvatarSize.lg => 40,
      };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final defaults = Theme.of(context).extension<DefaultTokens>();
    final ty = Theme.of(context).extension<ShadcnTypography>() ?? ShadcnTypography.defaults();
    final side = _side;

    final Color bg = backgroundColor ?? tokens.secondary; // neutro
    final Color fg = foregroundColor ?? tokens.secondaryForeground;

    final ImageProvider? provider = imageProvider ??
        (imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null);

    final border = showBorder ? Border.all(color: tokens.border, width: 1) : null;

    final List<BoxShadow> ring = showRing && defaults != null
        ? [BoxShadow(color: defaults.ring.withValues(alpha: 0.5), spreadRadius: 3, blurRadius: 0)]
        : const [];

    Widget child;
    if (provider != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: Image(
          image: provider,
          width: side,
          height: side,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Fallback(name: name, fg: fg, ty: ty),
        ),
      );
    } else {
      child = _Fallback(name: name, fg: fg, ty: ty);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: provider == null ? bg : null,
        border: border,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: ring,
      ),
      child: SizedBox(
        width: side,
        height: side,
        child: Center(child: child),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.name, required this.fg, required this.ty});

  final String? name;
  final Color fg;
  final ShadcnTypography ty;

  @override
  Widget build(BuildContext context) {
    final text = _initials(name);
    return Text(text,
        style: TextStyle(
          color: fg,
          fontSize: ty.textSm,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ));
  }

  String _initials(String? s) {
    if (s == null || s.trim().isEmpty) return '?';
    final parts = s.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}