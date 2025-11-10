// lib/components/dialog.dart
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per ShadcnRadii / DefaultTokens se presenti

/// API principale (equivalente a Dialog + DialogContent in shadcn)
/// Uso:
///   AppDialog.show(
///     context,
///     builder: (ctx) => AppDialogContent(
///       children: [
///         const AppDialogHeader(
///           title: AppDialogTitle('Edit profile'),
///           description: AppDialogDescription('Make changes to your profile here.'),
///         ),
///         // ...body
///         const AppDialogFooter(
///           // metti qui le azioni
///         ),
///       ],
///     ),
///   );
class AppDialog {
  /// Mostra un dialog con transizione fade+zoom (200ms) e overlay nero/50.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    bool showCloseButton = true,
  }) {
    final theme = Theme.of(context);
    final curve =
        theme.extension<DefaultTokens>()?.curveEaseOut ?? Curves.easeOut;

    return showGeneralDialog<T>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5), // bg-black/50
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim, secondaryAnim) {
        // Il contenuto vero viene fornito dal builder
        return SafeArea(
          child: Builder(
            builder: (ctx) {
              // wrappa in Stack per poter aggiungere il close button opzionale
              final content = builder(ctx);
              return Stack(
                children: [
                  // niente overlay qui: è gestito da barrierColor di showGeneralDialog
                  Center(child: content),
                  // Il close button lo posizioniamo dentro AppDialogContent,
                  // ma se il chiamante fornisse un widget custom, offriamo un
                  // fallback che non rompe il layout (nessun close extra).
                ],
              );
            },
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        // data-[state=open]:fade-in-0 + zoom-in-95
        final fade = CurvedAnimation(parent: anim, curve: Curves.linear);
        final scale = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: curve));
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}

/// Contenitore del contenuto (equivalente a `DialogContent`)
/// Mantiene:
/// - bg: surface
/// - rounded-lg
/// - border (outlineVariant)
/// - p-6
/// - shadow-lg
/// - max-w: sm:max-w-lg (640)
/// - w: calc(100% - 2rem) → margine 1rem per lato
class AppDialogContent extends StatelessWidget {
  const AppDialogContent({
    super.key,
    required this.children,
    this.showCloseButton = true,
    this.maxWidth,
    this.backgroundColor,
  });

  final List<Widget> children;
  final bool showCloseButton;
  final double? maxWidth; // override opzionale della larghezza massima
  final Color? backgroundColor; // override opzionale del colore di sfondo

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radii = theme.extension<ShadcnRadii>();
    final tokens = theme.extension<DefaultTokens>();

    final double horizontalMargin = 16; // 1rem per lato → calc(100% - 2rem)
    final double defaultMaxWidth = 640; // sm:max-w-lg
    final double usedMaxWidth = maxWidth ?? defaultMaxWidth;
    final double minWidth = 320; // evita pannelli troppo stretti
    final borderColor = cs.outline; // cs.outlineVariant → cs.outline (parità shadcn)
    final bgDefault = cs.inversePrimary; // default
    final bg = backgroundColor ?? bgDefault; // consente override (es. bg app)
    final fg = cs.onSurface;

    // focus ring per il close button: 3px con ring tokens se presenti
    final ringColor = tokens?.ring ?? cs.outline; // fallback outline come shadcn

    // Gruppo con gap=16 (gap-4)
    final body = DefaultTextStyle(
      style:
          theme.textTheme.bodyMedium?.copyWith(color: fg) ??
          TextStyle(color: fg, fontSize: 14),
      child: IconTheme(
        data: IconThemeData(size: 16, color: fg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _withGaps(children, gap: 16),
        ),
      ),
    );

    Widget panel = Material(
      color: bg,
      elevation: 8, // shadow-lg
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: radii?.lg ?? BorderRadius.circular(12), // rounded-lg
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24), // p-6
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Il contenuto determina l'altezza del pannello
            body,
            // Close button (in alto a destra)
            if (showCloseButton)
              Positioned(
                right: 16,
                // Regola fine per centrare verticalmente rispetto al titolo (circa linea di base di 16px)
                top: 10,
                child: _CloseButton(
                  ringColor: ringColor,
                  isDark: theme.brightness == Brightness.dark,
                ),
              ),
          ],
        ),
      ),
    );

    // Constrain + margin laterali tipo "w-full max-w-[calc(100%-2rem)] sm:max-w-lg"
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      constraints: BoxConstraints(
        minWidth: minWidth,
        maxWidth: usedMaxWidth,
        // altezza dinamica basata sul contenuto
      ),
      child: panel,
    );
  }

  static List<Widget> _withGaps(List<Widget> children, {required double gap}) {
    if (children.isEmpty) return const [];
    return [
      for (int i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ];
  }
}

/// Header (equivalente a `DialogHeader`)
/// - layout: colonna con gap-2, text-center su xs e sm:text-left
class AppDialogHeader extends StatelessWidget {
  const AppDialogHeader({
    super.key,
    this.title,
    this.description,
    this.textAlignStartBreakpoint = 600, // ~sm
    this.showCloseButton = false,
    this.gapBetweenTitleAndDescription = 8,
  });

  final Widget? title;
  final Widget? description;
  final double textAlignStartBreakpoint;
  /// Mostra il pulsante di chiusura direttamente nell'header (sulla stessa riga del titolo)
  final bool showCloseButton;
  /// Gap verticale tra titolo e descrizione (default 8)
  final double gapBetweenTitleAndDescription;

  @override
  Widget build(BuildContext context) {
    final isStart =
        MediaQuery.of(context).size.width >= textAlignStartBreakpoint;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<DefaultTokens>();
    final ringColor = tokens?.ring ?? cs.outline;
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> children = [];
    // Prima riga: titolo + eventuale close
    if (title != null || showCloseButton) {
      final firstRow = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (title != null)
            Expanded(child: title!)
          else
            const Expanded(child: SizedBox.shrink()),
          if (showCloseButton)
            _CloseButton(ringColor: ringColor, isDark: isDark),
        ],
      );
      children.add(firstRow);
    } else if (title != null) {
      children.add(title!);
    }
    // Gap e descrizione
    if (description != null) {
      if (children.isNotEmpty) children.add(SizedBox(height: gapBetweenTitleAndDescription));
      children.add(description!);
    }

    return Column(
      crossAxisAlignment:
          isStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: children,
    );
  }
}

/// Footer (equivalente a `DialogFooter`)
/// - layout: flex-col-reverse gap-2 sm:flex-row sm:justify-end
class AppDialogFooter extends StatelessWidget {
  const AppDialogFooter({super.key, this.children = const <Widget>[]});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isRow = MediaQuery.of(context).size.width >= 600;
    final content = isRow
        ? Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: _withSpacing(children, spacing: 8),
            ),
          )
        : Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: children.reversed.toList(),
            ),
          );

    return content;
  }

  static List<Widget> _withSpacing(
    List<Widget> children, {
    required double spacing,
  }) {
    if (children.isEmpty) return const [];
    return [
      for (int i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: spacing, height: spacing),
        children[i],
      ],
    ];
  }
}

/// Title (equivalente a `DialogTitle`) → text-lg font-semibold leading-none
class AppDialogTitle extends StatelessWidget {
  const AppDialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      text,
      style: (t.titleMedium ?? const TextStyle(fontSize: 16)).copyWith(
        fontWeight: FontWeight.w600,
        height: 1.0,
      ),
    );
  }
}

/// Description (equivalente a `DialogDescription`) → text-sm text-muted-foreground
class AppDialogDescription extends StatelessWidget {
  const AppDialogDescription(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final base = t.bodySmall ?? const TextStyle(fontSize: 12);
    // text-muted-foreground: onSurface con opacità più bassa
    final muted = base.copyWith(color: cs.onSurface.withValues(alpha: 0.65));
    return Text(text, style: muted);
  }
}

/// Close button con ring 3px (equivalente a data-slot="dialog-close")
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.ringColor, required this.isDark});

  final Color ringColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final radii = Theme.of(context).extension<ShadcnRadii>();
    return _FocusableIconButton(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.close, size: 16),
      // opacity-70 hover:opacity-100
      baseOpacity: 0.70,
      hoverOpacity: 1.0,
      ringColor: ringColor.withValues(alpha: isDark ? 0.40 : 0.50), // focus-visible:ring
      ringWidth: 2, // ring-2 (shadcn)
      borderRadius: radii?.xs ?? BorderRadius.circular(4), // rounded-xs
    );
  }
}

/// IconButton custom con stato hover/focus e ring
class _FocusableIconButton extends StatefulWidget {
  const _FocusableIconButton({
    required this.onPressed,
    required this.icon,
    this.baseOpacity = 1.0,
    this.hoverOpacity = 1.0,
    this.ringColor,
    this.ringWidth = 3,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  final VoidCallback onPressed;
  final Widget icon;
  final double baseOpacity;
  final double hoverOpacity;
  final Color? ringColor;
  final double ringWidth;
  final BorderRadius borderRadius;

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ringShadow = (_focused && widget.ringColor != null)
        ? [
            BoxShadow(
              blurRadius: 0,
              spreadRadius: widget.ringWidth.toDouble(),
              color: widget.ringColor!,
            ),
          ]
        : const <BoxShadow>[];

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: _hover ? widget.hoverOpacity : widget.baseOpacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: ringShadow, // focus-visible:ring
            ),
            child: InkWell(
              borderRadius: widget.borderRadius,
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.all(6), // hit slop come btn XS
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
