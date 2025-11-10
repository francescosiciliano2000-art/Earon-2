import 'package:flutter/material.dart';
import '../theme/theme_builder.dart';
import '../theme/themes.dart';
import 'checkbox.dart';
import '../icons/app_icons.dart';

/// Colonna tabellare moderna
class AppDataColumn {
  final String label;
  final double? width; // larghezza opzionale
  final TextAlign align;
  // Interazione opzionale su header (ordinamento)
  final VoidCallback? onLabelTap;
  // Indica se la colonna è ordinata e la direzione (true=asc, false=desc)
  final bool? sortAscending;
  const AppDataColumn({
    required this.label,
    this.width,
    this.align = TextAlign.left,
    this.onLabelTap,
    this.sortAscending,
  });
}

/// Riga tabellare
class AppDataRow {
  final List<Widget> cells;
  final Widget? rowMenu; // azioni contestuali
  final VoidCallback? onTap; // evento di tap sull'intera riga
  const AppDataRow({required this.cells, this.rowMenu, this.onTap});
}

/// Tabella moderna con header sticky, altezza compatta, zebra + hover highlight.
class AppDataTable extends StatefulWidget {
  final List<AppDataColumn> columns;
  final List<AppDataRow> rows;
  final double rowHeight;
  final double headerHeight;
  // Selezione opzionale (checkbox di riga + header "seleziona tutto")
  final bool selectable;
  final bool allSelected;
  final VoidCallback? onToggleAll;
  final List<bool>? selectedRows; // lunghezza deve corrispondere a rows
  final void Function(int rowIndex, bool selected)? onToggleRow;

  /// Se true, integra la colonna di selezione nella prima cella (es. "Nome")
  /// rimuovendo la colonna dedicata e il relativo divisorio verticale.
  final bool selectionInFirstCell;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowHeight = 54, // shadcn: h-10
    this.headerHeight = 42, // shadcn: h-10
    this.selectable = false,
    this.allSelected = false,
    this.onToggleAll,
    this.selectedRows,
    this.onToggleRow,
    this.selectionInFirstCell = false,
  });

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  // Due controller separati, sincronizzati tra loro.
  late final ScrollController _headerHController;
  late final ScrollController _bodyHController;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _headerHController = ScrollController();
    _bodyHController = ScrollController();
  }

  @override
  void dispose() {
    _headerHController.dispose();
    _bodyHController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gt = context.tokens;
    final dt = theme.extension<DefaultTokens>();
    final radii = theme.extension<ShadcnRadii>();

    double defaultColMin(AppDataColumn c) =>
        c.width ?? 140; // fallback minimo per colonna
    double minTableWidth() {
      final base =
          widget.columns.fold<double>(0, (sum, c) => sum + defaultColMin(c));
      final sel = (widget.selectable && !widget.selectionInFirstCell)
          ? 40.0
          : 0.0; // spazio checkbox
      return base + sel;
    }

    Widget headerRow() {
      return Container(
        height: widget.headerHeight,
        decoration: BoxDecoration(
          // ⬅️ header distinto (coerente con shadcn “secondary”)
          color: gt.secondary,
          // Bordo evidente anche in light mode: separazione netta
          // Include anche i lati per una cornice continua attorno all'header
          border: Border(
            top: BorderSide(color: gt.border),
            left: BorderSide(color: gt.border),
            right: BorderSide(color: gt.border),
            bottom: BorderSide(color: gt.border),
          ),
          // Arrotonda gli angoli superiori per evitare artefatti
          borderRadius: BorderRadius.only(
            topLeft: (radii?.md ?? dt?.radiusMd ?? BorderRadius.circular(8)).topLeft,
            topRight: (radii?.md ?? dt?.radiusMd ?? BorderRadius.circular(8)).topRight,
          ),
        ),
        child: _rowLayout(
          context,
          widget.columns,
          // header cells
          [
            for (int i = 0; i < widget.columns.length; i++)
              _buildHeaderCell(
                context,
                theme,
                radii,
                widget.columns[i],
                withLeadingSelect:
                    widget.selectable && widget.selectionInFirstCell && i == 0,
                allSelected: widget.allSelected,
                onToggleAll: widget.onToggleAll,
              ),
          ],
          isHeader: true,
          leading: (widget.selectable && !widget.selectionInFirstCell)
              ? Transform.translate(
                  offset: const Offset(0,
                      -2), // shadcn: [&:has([role=checkbox])]: translate-y-[2px]
                  child: AppCheckbox(
                    value: widget.allSelected,
                    onChanged: (_) => widget.onToggleAll?.call(),
                    size: 16,
                  ),
                )
              : null,
        ),
      );
    }

    Widget bodyList() {
      return ListView.builder(
        primary: false,
        shrinkWrap: false,
        itemCount: widget.rows.length,
        itemBuilder: (context, i) {
          final row = widget.rows[i];
          final selected = widget.selectedRows != null &&
              i < (widget.selectedRows!.length) &&
              (widget.selectedRows![i] == true);
          return _Hoverable(
            builder: (hovered) {
              // shadcn: hover:bg-muted/50, selected:bg-muted (niente zebra)
              final Color bg = selected
                  ? gt.muted
                  : (hovered ? gt.muted.withValues(alpha: 0.50) : Colors.transparent);

              // Eventuale iniezione della checkbox nella prima cella
              final cells = List<Widget>.from(row.cells);
              if (widget.selectable &&
                  widget.selectionInFirstCell &&
                  cells.isNotEmpty) {
                cells[0] = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -2), // allinea alla head
                      child: AppCheckbox(
                        value: selected,
                        onChanged: (v) => widget.onToggleRow?.call(i, v),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: cells[0]),
                  ],
                );
              }
              return InkWell(
                onTap: row.onTap,
                child: Container(
                  height: widget.rowHeight,
                  decoration: BoxDecoration(
                    color: bg,
                    // shadcn: border-b su tutte le righe (l’ultima tr può togliere il bordo se serve a valle)
                    border: Border(bottom: BorderSide(color: gt.border)),
                  ),
                  child: _rowLayout(
                    context,
                    widget.columns,
                    cells,
                    trailing: row.rowMenu,
                    leading: (widget.selectable && !widget.selectionInFirstCell)
                        ? Transform.translate(
                            offset: const Offset(0, -2),
                            child: AppCheckbox(
                              value: selected,
                              onChanged: (v) => widget.onToggleRow?.call(i, v),
                              size: 16,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    final outerRadius = radii?.md ?? dt?.radiusMd ?? BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: outerRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // ⬅️ bordo esterno + radius per angoli arrotondati
          border: Border.all(color: gt.border),
          borderRadius: outerRadius,
          // Sfondo coerente con surface evitando artefatti sui bordi
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            // Header orizzontale scrollabile (linkato al body)
            LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = minTableWidth();
                final viewportWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : minWidth;
                final tableWidth =
                    viewportWidth < minWidth ? minWidth : viewportWidth;
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (_syncing) return false;
                    if (n.metrics.axis == Axis.horizontal) {
                      _syncing = true;
                      if (_bodyHController.hasClients) {
                        _bodyHController.jumpTo(n.metrics.pixels);
                      }
                      _syncing = false;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _headerHController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: tableWidth,
                        maxWidth: tableWidth,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: outerRadius.topLeft,
                          topRight: outerRadius.topRight,
                        ),
                        child: headerRow(),
                      ),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // larghezza effettiva della tabella: almeno la somma minima delle colonne,
                  // altrimenti riempi lo spazio disponibile per evitare width non finite.
                  final minWidth = minTableWidth();
                  final viewportWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : minWidth;
                  final tableWidth =
                      viewportWidth < minWidth ? minWidth : viewportWidth;
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (_syncing) return false;
                      if (n.metrics.axis == Axis.horizontal) {
                        _syncing = true;
                        if (_headerHController.hasClients) {
                          _headerHController.jumpTo(n.metrics.pixels);
                        }
                        _syncing = false;
                      }
                      return false;
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: outerRadius.bottomLeft,
                        bottomRight: outerRadius.bottomRight,
                      ),
                      child: Scrollbar(
                        controller: _bodyHController,
                        trackVisibility: false,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _bodyHController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: tableWidth,
                              maxWidth: tableWidth,
                            ),
                            child: bodyList(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout di una riga con supporto larghezze e allineamenti
  Widget _rowLayout(
    BuildContext context,
    List<AppDataColumn> cols,
    List<Widget> cells, {
    bool isHeader = false,
    Widget? trailing,
    Widget? leading,
  }) {
    // Fail-safe: se il numero di celle non corrisponde alle colonne,
    // adatta/riempi per evitare errori di build che nasconderebbero l'intera tabella.
    if (cols.length != cells.length) {
      final fixed = <Widget>[];
      final minLen = cols.length;
      for (int i = 0; i < minLen; i++) {
        fixed.add(i < cells.length ? cells[i] : const SizedBox.shrink());
      }
      cells = fixed;
    }
    final theme = Theme.of(context);

    return Row(
      children: [
        if (leading != null)
          SizedBox(
            width: 40,
            child: Padding(
              // shadcn: quando c’è checkbox, niente padding-right extra
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: leading,
              ),
            ),
          ),
        for (int i = 0; i < cols.length; i++)
          SizedBox(
            width: cols[i].width ?? 140, // larghezza di colonna
            // shadcn: niente border-left tra celle; border gestito a livello di riga/header
            child: Padding(
              // head: px-2 ; cell: p-2
              padding: isHeader
                  ? const EdgeInsets.symmetric(horizontal: 8)
                  : const EdgeInsets.all(8),
              child: Align(
                alignment: _alignFor(cols[i].align),
                child: DefaultTextStyle.merge(
                  style: isHeader
                      ? theme.textTheme.labelLarge!
                      : theme.textTheme.bodyMedium!,
                  child: cells[i],
                ),
              ),
            ),
          ),
        if (trailing != null) ...[
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: trailing,
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    ThemeData theme,
    ShadcnRadii? r,
    AppDataColumn c, {
    required bool withLeadingSelect,
    required bool allSelected,
    required VoidCallback? onToggleAll,
  }) {
    final label = InkWell(
      onTap: c.onLabelTap,
      borderRadius: r?.sm ?? BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.label, style: theme.textTheme.labelLarge),
          if (c.sortAscending != null)
            Icon(
              c.sortAscending! ? AppIcons.arrowUp : AppIcons.arrowDown,
              size: 16,
              color: context.tokens.mutedForeground,
            ),
        ],
      ),
    );

    if (!withLeadingSelect) return label;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, -2), // shadcn: rialzo checkbox
          child: AppCheckbox(
            value: allSelected,
            onChanged: (_) => onToggleAll?.call(),
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: label),
      ],
    );
  }

  Alignment _alignFor(TextAlign a) => switch (a) {
        TextAlign.left => Alignment.centerLeft,
        TextAlign.center => Alignment.center,
        TextAlign.right => Alignment.centerRight,
        _ => Alignment.centerLeft,
      };
}

// Wrapper per fornire stato hover
class _Hoverable extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  const _Hoverable({required this.builder});

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!mounted) return;
        setState(() => _hover = true);
      },
      onExit: (_) {
        if (!mounted) return;
        setState(() => _hover = false);
      },
      child: widget.builder(_hover),
    );
  }
}
