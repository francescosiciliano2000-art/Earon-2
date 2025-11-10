import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/themes.dart';

// ---- DATA ----
class MultiSelectItemData {
  final String value;
  final String label;
  final bool enabled;
  const MultiSelectItemData({
    required this.value,
    required this.label,
    this.enabled = true,
  });
}

class MultiSelectGroupData {
  final String label;
  final List<MultiSelectItemData> items;
  const MultiSelectGroupData({required this.label, required this.items});
}

enum MultiSelectSize { sm, md }

class AppMultiSelect extends StatefulWidget {
  final List<MultiSelectGroupData> groups;
  final List<String> values;
  final String? placeholder;
  final double width;
  final ValueChanged<List<String>>? onChanged;
  final bool enabled;
  final bool isInvalid;
  final MultiSelectSize size;

  const AppMultiSelect({
    super.key,
    required this.groups,
    this.values = const [],
    this.placeholder,
    this.onChanged,
    this.width = 220,
    this.enabled = true,
    this.isInvalid = false,
    this.size = MultiSelectSize.md,
  });

  @override
  State<AppMultiSelect> createState() => _AppMultiSelectState();
}

class _AppMultiSelectState extends State<AppMultiSelect>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _overlayFocus = FocusNode();
  final ScrollController _menuScroll = ScrollController();
  OverlayEntry? _entry;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  late List<String> _selected;
  bool _hovered = false;
  bool _focusVisible = false;
  Size _triggerSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.values);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant AppMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      _selected = List.of(widget.values);
      // ⚠️ Non ricostruire l’overlay DURANTE il build; fallo al frame successivo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _entry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    // Chiudi l’overlay senza animazione e senza toccare il controller
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
    _menuScroll.dispose();
    _overlayFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });

    // Aggiorna subito la UI del menu — ma al prossimo frame per evitare conflitti
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _entry?.markNeedsBuild();
      widget.onChanged?.call(List.of(_selected));
    });
  }

  void _openOverlay() {
    if (_entry != null) return;

    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    _triggerSize = box?.size ?? Size(widget.width, 36);

    _entry = OverlayEntry(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      final tokens = Theme.of(context).extension<DefaultTokens>();
      final radii = Theme.of(context).extension<ShadcnRadii>();
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final baseBorderColor = widget.isInvalid
          ? cs.error
          : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);

      final Color ringBase =
          widget.isInvalid ? cs.error : (tokens?.ring ?? cs.outlineVariant);
      final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
      final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);

      final menu = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.width,
          maxWidth: widget.width,
          maxHeight: 320,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                radii?.md ?? const BorderRadius.all(Radius.circular(6)),
            border: Border.all(color: baseBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView(
            controller: _menuScroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            children: _buildMenuChildren(isDark),
          ),
        ),
      );

      // allineamento overlay
      final screen = MediaQuery.of(context).size;
      final overlayW = widget.width;
      final triggerBox =
          _triggerKey.currentContext!.findRenderObject() as RenderBox;
      final triggerOffset = triggerBox.localToGlobal(Offset.zero);
      final spaceRight = screen.width - (triggerOffset.dx + _triggerSize.width);
      final bool alignRight = spaceRight < overlayW - _triggerSize.width;
      final offsetX = alignRight ? _triggerSize.width - overlayW : 0.0;

      return Stack(
        children: [
          Positioned.fill(child: GestureDetector(onTap: _removeOverlay)),
          CompositedTransformFollower(
            link: _layerLink,
            offset: Offset(offsetX, _triggerSize.height + 8),
            showWhenUnlinked: false,
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topRight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: _focusVisible
                          ? [BoxShadow(color: focusRingColor, spreadRadius: 3)]
                          : [],
                    ),
                    child: Focus(
                      focusNode: _overlayFocus,
                      onFocusChange: (v) => setState(() => _focusVisible = v),
                      child: menu,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    _controller.forward();
  }

  void _removeOverlay() {
    if (_entry == null) return;
    // Chiudi senza animazione se l’anim controller è già stato dismesso
    final canAnimate = _controller.status != AnimationStatus.dismissed;
    if (canAnimate) {
      _controller.reverse();
    }
    _entry?.remove();
    _entry = null;
  }

  String _labelText() {
    if (_selected.isEmpty) return widget.placeholder ?? 'Seleziona…';
    return '${_selected.length} colonne';
    // (se vuoi mostrare le etichette: return _selected.join(', ');)
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DefaultTokens>();
    final radii = Theme.of(context).extension<ShadcnRadii>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final height = switch (widget.size) {
      MultiSelectSize.sm => 32.0,
      MultiSelectSize.md => 36.0,
    };

    final baseBorderColor = widget.isInvalid
        ? cs.error
        : (isDark ? Colors.white.withValues(alpha: 0.15) : cs.outline);
    final Color ringBase =
        widget.isInvalid ? cs.error : (tokens?.ring ?? cs.outlineVariant);
    final double ringAlpha = widget.isInvalid ? (isDark ? 0.40 : 0.20) : 0.50;
    final Color focusRingColor = ringBase.withValues(alpha: ringAlpha);
    final focusBorderColor = ringBase;

    Color baseBg = isDark ? cs.surface.withValues(alpha: 0.08) : cs.surface;
    if (isDark && _hovered) baseBg = cs.surface.withValues(alpha: 0.12);

    final ringShadow = _focusVisible
        ? [BoxShadow(color: focusRingColor, spreadRadius: 3)]
        : [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 1)
          ];

    final borderColor = _focusVisible ? focusBorderColor : baseBorderColor;
    final textColor = cs.onSurface;
    final muted =
        isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF6B7280);

    final trigger = SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: AnimatedContainer(
          key: _triggerKey,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius:
                radii?.md ?? const BorderRadius.all(Radius.circular(6)),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: ringShadow,
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: InkWell(
              borderRadius:
                  radii?.md ?? const BorderRadius.all(Radius.circular(6)),
              onTap: widget.enabled ? _openOverlay : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _labelText(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _selected.isEmpty ? muted : textColor,
                            ),
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretDown(PhosphorIconsStyle.regular),
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        onFocusChange: (v) => setState(() => _focusVisible = v),
        child: trigger,
      ),
    );
  }

  List<Widget> _buildMenuChildren(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<ShadcnRadii>();

    final children = <Widget>[];
    for (final group in widget.groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Text(
          group.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: isDark
                    ? cs.onSurface.withValues(alpha: 0.6)
                    : const Color(0xFF6B7280),
              ),
        ),
      ));

      for (final item in group.items) {
        final selected = _selected.contains(item.value);
        children.add(_MenuItemLikeSelect(
          label: item.label,
          selected: selected,
          enabled: item.enabled,
          onTap: item.enabled ? () => _toggle(item.value) : null,
          radius: radii?.md ?? const BorderRadius.all(Radius.circular(6)),
        ));
      }
    }
    return children;
  }
}

/// Stile "Select": SOLO hover su mouse-over (rounded, più stretto),
/// nessun background persistente per gli elementi già selezionati.
/// Mostra la spunta a destra quando selected == true.
class _MenuItemLikeSelect extends StatefulWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final BorderRadius radius;

  const _MenuItemLikeSelect({
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
    required this.radius,
  });

  @override
  State<_MenuItemLikeSelect> createState() => _MenuItemLikeSelectState();
}

class _MenuItemLikeSelectState extends State<_MenuItemLikeSelect> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hoverBg = isDark
        ? cs.onSurface.withValues(alpha: 0.08)
        : cs.surfaceContainerHighest;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        borderRadius: widget.radius,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 36,
          decoration: BoxDecoration(
            color: _hover ? hoverBg : Colors.transparent,
            borderRadius: widget.radius,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.enabled
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.4),
                      ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.check, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
