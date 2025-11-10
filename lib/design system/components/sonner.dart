// lib/components/sonner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/themes.dart'; // per ShadcnRadii / DefaultTokens
import '../theme/oklch.dart'; // per colori OKLCH (parità CSS)
// spinner.dart non utilizzato: l'icona di loading usa CircularProgressIndicator

/// Tipi di toast in linea col mapping icone di sonner.tsx
enum AppToastType { success, info, warning, error, loading }

/// Icone di default (se non sovrascritte via props)
Icon _defaultIcon(AppToastType type, Color color) {
  switch (type) {
    case AppToastType.success:
      return Icon(Icons.check_circle, size: 16, color: color);
    case AppToastType.info:
      return Icon(Icons.info, size: 16, color: color);
    case AppToastType.warning:
      return Icon(Icons.warning_amber_rounded, size: 16, color: color);
    case AppToastType.error:
      return Icon(Icons.error_rounded, size: 16, color: color);
    case AppToastType.loading:
      return Icon(Icons.autorenew, size: 16, color: color);
  }
}

/// Parametri per singolo toast
class AppToast {
  final String title;
  final String? description;
  final AppToastType type;
  final Duration? duration; // se null e loading => non auto-close
  final VoidCallback? onTap;

  AppToast({
    required this.title,
    this.description,
    this.type = AppToastType.info,
    this.duration,
    this.onTap,
  });
}

/// Proprietà opzionali del contenitore Toaster (equivalenti a ToasterProps usate nel file TS)
class AppToasterProps {
  final Alignment alignment; // default: topRight come Sonner
  final EdgeInsets margin;
  final double gap;
  final Map<AppToastType, Widget>? icons;
  // Override stile "normal" in linea con style vars del TS: --normal-bg, --normal-text, --normal-border, --border-radius
  final Color? normalBg;
  final Color? normalText;
  final Color? normalBorder;
  final BorderRadius? borderRadius;

  const AppToasterProps({
    this.alignment = Alignment.topCenter,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.gap = 8,
    this.icons,
    this.normalBg,
    this.normalText,
    this.normalBorder,
    this.borderRadius,
  });
}

/// Widget da montare UNA volta (es. in MaterialApp.builder o in cima allo Scaffold)
class AppToaster extends StatefulWidget {
  // GlobalKey per consentire accesso anche quando il Toaster è montato come "sibling" (es. in uno Stack)
  static final GlobalKey<AppToasterState> globalKey = GlobalKey<AppToasterState>();

  final AppToasterProps props;

  const AppToaster({super.key, this.props = const AppToasterProps()});

  /// Accesso dal basso: AppToaster.of(context).show(...)
  static AppToasterState of(BuildContext context) {
    // Prova prima con il GlobalKey (funziona anche se AppToaster non è antenato diretto)
    final viaGlobal = globalKey.currentState;
    if (viaGlobal != null) return viaGlobal;
    // Fallback: cerca tra gli antenati
    final state = context.findAncestorStateOfType<AppToasterState>();
    assert(state != null, 'AppToaster non trovato nell’albero');
    return state!;
  }

  @override
  State<AppToaster> createState() => AppToasterState();
}

class _ToastEntry {
  final String id;
  final AppToast data;
  _ToastEntry(this.id, this.data);
}

class AppToasterState extends State<AppToaster> with TickerProviderStateMixin {
  final List<_ToastEntry> _toasts = [];

  /// API: mostra un toast
  String show(AppToast toast) {
    final id = UniqueKey().toString();
    final entry = _ToastEntry(id, toast);
    setState(() => _toasts.insert(0, entry)); // newest on top

    final isLoading = toast.type == AppToastType.loading;
    final d =
        toast.duration ??
        (isLoading ? null : const Duration(milliseconds: 3500));

    if (d != null) {
      Timer(d, () => dismiss(id));
    }
    return id;
  }

  /// API helper
  String success(
    String title, {
    String? description,
    Duration? duration,
    VoidCallback? onTap,
  }) {
    // Sostituisci il loading più recente (se presente) con success
    final idx = _toasts.indexWhere((e) => e.data.type == AppToastType.loading);
    final toast = AppToast(
      title: title,
      description: description,
      duration: duration,
      onTap: onTap,
      type: AppToastType.success,
    );
    if (idx != -1) {
      final id = _toasts[idx].id;
      setState(() => _toasts[idx] = _ToastEntry(id, toast));
      final d = toast.duration ?? const Duration(milliseconds: 3500);
      Timer(d, () => dismiss(id));
      return id;
    }
    return show(toast);
  }

  String info(
    String title, {
    String? description,
    Duration? duration,
    VoidCallback? onTap,
  }) => show(
    AppToast(
      title: title,
      description: description,
      duration: duration,
      onTap: onTap,
      type: AppToastType.info,
    ),
  );

  String warning(
    String title, {
    String? description,
    Duration? duration,
    VoidCallback? onTap,
  }) => show(
    AppToast(
      title: title,
      description: description,
      duration: duration,
      onTap: onTap,
      type: AppToastType.warning,
    ),
  );

  String error(
    String title, {
    String? description,
    Duration? duration,
    VoidCallback? onTap,
  }) => show(
    AppToast(
      title: title,
      description: description,
      duration: duration,
      onTap: onTap,
      type: AppToastType.error,
    ),
  );

  String loading(
    String title, {
    String? description,
    VoidCallback? onTap,
  }) => show(
    AppToast(
      title: title,
      description: description,
      duration: null,
      onTap: onTap,
      type: AppToastType.loading,
    ),
  ); // no auto-close

  void dismiss(String id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((e) => e.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // unused: final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // "var(--popover)" / "var(--popover-foreground)" / "var(--border)" (parità CSS)
    final bg = widget.props.normalBg ?? (isDark ? oklch(0.269, 0.0, 0.0) : const Color(0xFFFFFFFF));
    final fg = widget.props.normalText ?? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0A0A0A));
    final border = widget.props.normalBorder ?? (isDark ? oklch(1.0, 0.0, 0.0, alpha: 0.10) : const Color.fromRGBO(229, 229, 229, 1.0));

    // Radius esatto: var(--radius) = 0.625rem ≈ 10px
    final defaultRadius = BorderRadius.circular(10);
    final radius = widget.props.borderRadius ?? defaultRadius;

    final curve =
        theme.extension<DefaultTokens>()?.curveEaseOut ?? Curves.easeOut;

    final align = widget.props.alignment;
    final isTop = align.y <= 0;
    final isRight = align.x >= 0;

    final children = _toasts
        .map(
          (e) => _ToastCard(
            key: ValueKey(e.id),
            toast: e.data,
            onClose: () => dismiss(e.id),
            bg: bg,
            fg: fg,
            border: border,
            radius: radius,
            curve: curve,
            icons: widget.props.icons,
          ),
        )
        .toList();

    return IgnorePointer(
      ignoring: true, // pass-through (cliccabile solo sulle card con Listener)
      child: SafeArea(
        child: Align(
          alignment: align,
          child: Padding(
            padding: widget.props.margin,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: (align.x == 0)
                  ? CrossAxisAlignment.center
                  : (isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start),
              children: isTop ? children : children.reversed.toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final AppToast toast;
  final VoidCallback onClose;
  final Color bg;
  final Color fg;
  final Color border;
  final BorderRadius radius;
  final Curve curve;
  final Map<AppToastType, Widget>? icons;

  const _ToastCard({
    super.key,
    required this.toast,
    required this.onClose,
    required this.bg,
    required this.fg,
    required this.border,
    required this.radius,
    required this.curve,
    this.icons,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Evidenziazione per variant error: icona e title rossi
    final Color errorAccent = Theme.of(context).colorScheme.error;
    final bool isError = widget.toast.type == AppToastType.error;

    // Colore icone: neutro per tutti tranne error (rosso)
    final iconColor = isError ? errorAccent : widget.fg;

    final Widget icon =
      widget.icons != null && widget.icons!.containsKey(widget.toast.type)
        ? widget.icons![widget.toast.type]!
        : (widget.toast.type == AppToastType.loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                )
              : _defaultIcon(widget.toast.type, iconColor));

    // Animazione: fade + slide lieve verso il basso, simile a Sonner
    final fade = CurvedAnimation(parent: _a, curve: widget.curve);
    final slide = Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero).animate(_a);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.radius,
              boxShadow: isDark
                  ? const []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Material(
              color: widget.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: widget.radius,
                side: BorderSide(color: widget.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _ToastInk(
                onTap: widget.toast.onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44, maxWidth: 420),
                  child: Padding(
                    // p-3 (12px), gap-2 (8px)
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // icona
                        SizedBox(width: 22, height: 22, child: Center(child: icon)),
                        const SizedBox(width: 8),
                        // testo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // title
                              Text(
                                widget.toast.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isError ? errorAccent : widget.fg,
                                ),
                              ),
                              // description
                              if (widget.toast.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    widget.toast.description!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: widget.fg.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // chiusura manuale (solo se non loading)
                        if (widget.toast.type != AppToastType.loading)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: InkWell(
                              onTap: widget.onClose,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: Center(
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: widget.fg.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// (rimosso duplicato di _ToastInk: usare la versione in fondo al file con IgnorePointer)

// Rimosso _ToastTexts inutilizzato


/// Abilita il tap (il contenitore esterno ha IgnorePointer=true per pass-through)
class _ToastInk extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _ToastInk({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: onTap == null,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// -------- Helper globali opzionali (stile "sonner") --------

void toastSuccess(
  BuildContext context,
  String title, {
  String? description,
  Duration? duration,
  VoidCallback? onTap,
}) => AppToaster.of(
  context,
).success(title, description: description, duration: duration, onTap: onTap);

void toastInfo(
  BuildContext context,
  String title, {
  String? description,
  Duration? duration,
  VoidCallback? onTap,
}) => AppToaster.of(
  context,
).info(title, description: description, duration: duration, onTap: onTap);

void toastWarning(
  BuildContext context,
  String title, {
  String? description,
  Duration? duration,
  VoidCallback? onTap,
}) => AppToaster.of(
  context,
).warning(title, description: description, duration: duration, onTap: onTap);

void toastError(
  BuildContext context,
  String title, {
  String? description,
  Duration? duration,
  VoidCallback? onTap,
}) => AppToaster.of(
  context,
).error(title, description: description, duration: duration, onTap: onTap);

void toastLoading(
  BuildContext context,
  String title, {
  String? description,
  VoidCallback? onTap,
}) => AppToaster.of(
  context,
).loading(title, description: description, onTap: onTap);
