import 'package:flutter/material.dart';
import './button.dart';

/// Pagination (wrapper <nav>)
/// Replica la struttura shadcn/ui:
/// Pagination -> PaginationContent (ul) -> PaginationItem (li) -> PaginationLink (a)
/// Varianti visuali: link attivo = accent (bg-accent text-accent-foreground), link normale = ghost.
class Pagination extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget? child;

  const Pagination({super.key, this.padding = EdgeInsets.zero, this.child});

  @override
  Widget build(BuildContext context) {
    // In shadcn: "mx-auto flex w-full justify-center"
    return Semantics(
      container: true,
      label: 'pagination',
      child: Padding(
        padding: padding,
        child: Align(
          alignment: Alignment.center,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Contenitore orizzontale con gap=4px (gap-1 in Tailwind)
class PaginationContent extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const PaginationContent({
    super.key,
    required this.children,
    this.gap = 4.0, // gap-1
  });

  @override
  Widget build(BuildContext context) {
    // In shadcn: "flex flex-row items-center gap-1"
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _withGaps(children, gap),
    );
  }

  List<Widget> _withGaps(List<Widget> items, double gap) {
    if (items.isEmpty) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(SizedBox(width: gap));
      }
    }
    return out;
  }
}

/// Item singolo (li) — lasciato neutro come nello shadcn
class PaginationItem extends StatelessWidget {
  final Widget child;
  const PaginationItem({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(container: true, child: child);
  }
}

/// Link numerico della pagination
/// - isActive: controlla la variante visuale (accent vs ghost)
/// - size: di default "icon", come nello shadcn originale.
class PaginationLink extends StatelessWidget {
  final bool isActive;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final Widget child;
  final String? semanticsLabel;

  const PaginationLink({
    super.key,
    required this.child,
    this.onPressed,
    this.isActive = false,
    this.size = AppButtonSize.icon,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    // In shadcn, la pagina selezionata è bg-accent text-accent-foreground.
    // Qui usiamo la variante "secondary" ma sovrascriviamo i token in modo che
    // secondary == accent (accentBg/accentFg). In questo modo otteniamo un fill
    // persistente e coerente in light/dark mode.
    final cs = Theme.of(context).colorScheme;
    final base = AppButtonTokens.fromScheme(cs);

    final AppButtonVariant variant = isActive ? AppButtonVariant.secondary : AppButtonVariant.ghost;

    final AppButtonTokens? tokens = isActive
        ? AppButtonTokens(
            primary: base.primary,
            onPrimary: base.onPrimary,
            destructive: base.destructive,
            onDestructive: base.onDestructive,
            // Forziamo secondary a comportarsi come accent
            secondary: base.accentBg,
            onSecondary: base.accentFg,
            accentBg: base.accentBg,
            accentFg: base.accentFg,
            background: base.background,
            input: base.input,
            border: base.border,
            ring: base.ring,
          )
        : null;

    return Semantics(
      button: true,
      selected: isActive,
      label: semanticsLabel,
      child: AppButton(
        onPressed: onPressed,
        variant: variant,
        size: size,
        tokens: tokens,
        child: child,
      ),
    );
  }
}

/// Bottone "Previous" con icona a sinistra.
/// In shadcn size="default", padding orizzontale ≈ px-2.5; etichetta visibile da "sm" in su.
class PaginationPrevious extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const PaginationPrevious({
    super.key,
    this.onPressed,
    this.label = 'Previous',
  });

  @override
  Widget build(BuildContext context) {
    final showText = _showSmLabel(context);
    return AppButton(
      onPressed: onPressed,
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.default_,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // px-2.5 + py-2
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_left, size: 16),
          if (showText) const SizedBox(width: 4), // gap-1
          if (showText) Text(label),
        ],
      ),
    );
  }
}

/// Bottone "Next" con icona a destra.
/// In shadcn size="default", padding orizzontale ≈ px-2.5; etichetta visibile da "sm" in su.
class PaginationNext extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const PaginationNext({
    super.key,
    this.onPressed,
    this.label = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    final showText = _showSmLabel(context);
    return AppButton(
      onPressed: onPressed,
      variant: AppButtonVariant.ghost,
      size: AppButtonSize.default_,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // px-2.5 + py-2
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showText) Text(label),
          if (showText) const SizedBox(width: 4), // gap-1
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }
}

/// Ellissi (More pages) — size 36 come size-9 di Tailwind.
class PaginationEllipsis extends StatelessWidget {
  const PaginationEllipsis({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'More pages',
      child: SizedBox(
        width: 36,
        height: 36,
        child: Center(child: Icon(Icons.more_horiz, size: 16)),
      ),
    );
  }
}

/// Helper: emula "hidden sm:block" dello shadcn.
/// Mostra il testo solo se larghezza >= 640px (breakpoint "sm").
bool _showSmLabel(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= 640;
}
