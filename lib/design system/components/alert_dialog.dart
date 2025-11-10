// lib/design system/components/alert_dialog.dart
import 'package:flutter/material.dart';
// import '../theme/themes.dart'; // <- rimosso: non utilizzato
import 'dialog.dart';
import 'button.dart';

/// AppAlertDialog — porting 1:1 di `AlertDialog` (shadcn/ui + Radix)
class AppAlertDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? description,
    Widget? body,
    String cancelText = 'Cancel',
    String confirmText = 'Continue',
    VoidCallback? onCancel,
    required VoidCallback onConfirm,
    bool destructive = false,
    bool barrierDismissible = false,
  }) {
    return AppDialog.show<T>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        return AppAlertDialogContent(
          children: [
            AppAlertDialogHeader(
              title: AppAlertDialogTitle(title),
              description: description != null
                  ? AppAlertDialogDescription(description)
                  : null,
            ),
            if (body != null) body,
            AppAlertDialogFooter(
              children: [
                AppButton(
                  variant: AppButtonVariant.outline,
                  label: cancelText,
                  onPressed: () {
                    Navigator.of(ctx).maybePop();
                    onCancel?.call();
                  },
                ),
                AppButton(
                  variant: destructive
                      ? AppButtonVariant.destructive
                      : AppButtonVariant.default_,
                  label: confirmText,
                  onPressed: () {
                    Navigator.of(ctx).maybePop();
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Content: usa composizione invece di estendere AppDialogContent
class AppAlertDialogContent extends StatelessWidget {
  const AppAlertDialogContent({
    super.key,
    required this.children,
    this.borderRadius,
    this.maxWidth,
  });

  final List<Widget> children;
  final BorderRadius? borderRadius;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    // Se AppDialogContent supporta borderRadius/maxWidth li passiamo,
    // altrimenti commentali e lascia i default del tuo AppDialogContent.
    return AppDialogContent(
      // borderRadius: borderRadius,
      // maxWidth: maxWidth,
      showCloseButton: false, // rimuove la "x" di chiusura: c'è già il bottone Annulla
      maxWidth: 512, // larghezza fissa richiesta
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // bg uguale all’app
      children: children,
    );
  }
}

/// Header: col + gap-2; center su XS, left da sm in su (≈ Tailwind sm:)
class AppAlertDialogHeader extends StatelessWidget {
  const AppAlertDialogHeader({
    super.key,
    this.title,
    this.description,
    this.padding,
    this.centerOnSmall = true,
  });

  final Widget? title;
  final Widget? description;
  final EdgeInsetsGeometry? padding;
  final bool centerOnSmall;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final textAlign =
        (centerOnSmall && width < 640) ? TextAlign.center : TextAlign.start;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Align(
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: textAlign == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) title!,
            if (description != null) ...[
              const SizedBox(height: 8), // gap-2
              description!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Footer: sempre allineato a destra; su schermi piccoli usa Wrap per andare a capo se necessario
class AppAlertDialogFooter extends StatelessWidget {
  const AppAlertDialogFooter({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isSmall = width < 640;
    final buttons = children; // mantieni l'ordine Annulla -> Elimina

    return Padding(
      padding: EdgeInsets.zero,
      child: isSmall
          ? Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: buttons,
              ),
            )
          : Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: _withGaps(buttons, gap: 8),
              ),
            ),
    );
  }
}

/// Title: text-lg font-semibold
class AppAlertDialogTitle extends StatelessWidget {
  const AppAlertDialogTitle(this.text, {super.key});
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

/// Description: text-sm text-muted-foreground
class AppAlertDialogDescription extends StatelessWidget {
  const AppAlertDialogDescription(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Sostituisce withOpacity (deprecato) con withValues
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: cs.onSurface.withValues(alpha: 0.70),
      ),
    );
  }
}

List<Widget> _withGaps(List<Widget> children, {required double gap}) {
  final List<Widget> out = [];
  for (var i = 0; i < children.length; i++) {
    out.add(children[i]);
    if (i != children.length - 1) out.add(SizedBox(width: gap, height: gap));
  }
  return out;
}
