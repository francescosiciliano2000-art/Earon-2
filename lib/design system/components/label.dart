// lib/components/label.dart
import 'package:flutter/material.dart';

/// AppLabel — equivalente Flutter del componente `Label` di shadcn.
/// - Tipografia: text-sm, font-medium, leading-none
/// - Layout: inline-flex (Row) con gap-2
/// - Stato disabled: pointer-events none + opacity 0.5
/// - Stato peerDisabled: emula `peer-disabled:cursor-not-allowed` + `peer-disabled:opacity-50`
/// - Supporto "for": se passi [controlFocusNode], il tap del label mette a fuoco il controllo associato.
class AppLabel extends StatelessWidget {
  AppLabel({
    super.key,
    this.children,
    this.text,
    this.gap = 8.0, // gap-2
    this.disabled = false,
    this.peerDisabled = false,
    this.onTap,
    this.controlFocusNode,
    this.cursorWhenDisabled,
    this.cursor,
    this.style,
  }) : assert(
          (children != null && children.isNotEmpty) || (text != null),
          'Passa children oppure text',
        );

  /// Contenuto del label in forma di lista (es. icona + testo).
  final List<Widget>? children;

  /// Alternativa rapida quando serve solo testo.
  final String? text;

  /// Spaziatura orizzontale tra gli elementi (equiv. gap-2).
  final double gap;

  /// Se true: disabilita interazioni e abbassa l’opacità (0.5).
  final bool disabled;

  /// Se true: emula lo stato disabled del controllo associato (peer).
  /// In questo stato il label cambia cursore e opacità, ma NON blocca i pointer events.
  final bool peerDisabled;

  /// Tap handler opzionale. Se non fornito e [controlFocusNode] è presente,
  /// il tap proverà a dare focus al controllo associato.
  final VoidCallback? onTap;

  /// FocusNode del controllo “peer” (equivalente htmlFor).
  final FocusNode? controlFocusNode;

  /// Cursor quando il label è disabilitato.
  final MouseCursor? cursorWhenDisabled;

  /// Cursor quando il label è abilitato.
  final MouseCursor? cursor;

  /// Stile testo personalizzato (viene unito a quello di tema).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final weight = brightness == Brightness.light ? FontWeight.w600 : FontWeight.w500;

    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      // text-sm + font-medium/semibold + leading-none
      fontWeight: weight,
      height: 1.0, // leading-none
    );

    // Colore testo: usa il DefaultTextStyle corrente; non forziamo colori
    // per rispettare il tema globale (chiaro/scuro) come fa shadcn.
    final effectiveTextStyle =
        (baseStyle?.merge(style)) ?? style ?? const TextStyle();

    // Costruiamo i children: se è stato passato [text], lo convertiamo in Text.
    final contentChildren = <Widget>[
      if (children != null && children!.isNotEmpty)
        ..._intersperseGap(children!, gap),
      if (text != null) Text(text!, style: effectiveTextStyle),
    ];

    final body = DefaultTextStyle.merge(
      style: effectiveTextStyle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // items-center
        children: contentChildren.isEmpty
            ? [const SizedBox.shrink()]
            : contentChildren,
      ),
    );

    // Gestione interazioni: pointer-events none + opacity 0.5 se disabled.
    final interactive = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled
          ? null
          : () {
              if (onTap != null) {
                onTap!();
              } else if (controlFocusNode != null &&
                  controlFocusNode!.canRequestFocus) {
                controlFocusNode!.requestFocus();
              }
            },
      child: body,
    );

    // Cursor coerente con peer-disabled: not-allowed
    final effectiveDisabledCursor =
        cursorWhenDisabled ?? SystemMouseCursors.forbidden;
    final effectiveCursor = cursor ?? SystemMouseCursors.click;

    final withCursor = MouseRegion(
      cursor: (disabled || peerDisabled) ? effectiveDisabledCursor : effectiveCursor,
      child: interactive,
    );

    // Opacity come `group-data-[disabled=true]:opacity-50` / `peer-disabled:opacity-50`
    final withOpacity = AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: (disabled || peerDisabled) ? 0.5 : 1.0,
      child: withCursor,
    );

    // IgnorePointer come `pointer-events-none` su group disabled
    return IgnorePointer(ignoring: disabled, child: withOpacity);
  }

  /// Inserisce uno SizedBox largo [gap] tra i widget (equiv. gap-*).
  static List<Widget> _intersperseGap(List<Widget> items, double gap) {
    if (items.length <= 1) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(SizedBox(width: gap));
    }
    return out;
  }
}
