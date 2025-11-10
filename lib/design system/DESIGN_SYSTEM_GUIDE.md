Guida completa all’uso del Design System Flutter (shadcn/ui)
Questa guida spiega come usare correttamente il design system Flutter presente in lib/components e lib/theme, come configurare i token e come comporre i componenti nelle varianti principali per un’app SaaS.
1) Setup del tema e Toaster globale
In main.dart assicurati di:
// Tema neutrale + estensioni
final base = GlobalTheme.dark(); // oppure GlobalTheme.lightNeutrals()
final theme = DefaultTheme.apply(base);

// Monta il Toaster globale
MaterialApp.builder: (context, child) => Stack(
  children: [
    child!,
    const AppToaster(),
  ],
);
GlobalTokens: caricati da lib/theme/colors/*.json e agganciati come ThemeExtension
(background, foreground, border, ring, ecc.).
Accedi con:
final tokens = Theme.of(context).extension<GlobalTokens>();
Radii e Typography: disponibili come ThemeExtensions (ShadcnRadii, ShadcnTypography) da themes.dart.

2) Convenzioni generali
Varianti e stati seguono shadcn/ui: focus ring 3px, hover/pressed, disabled con opacity 0.5.
Usa sempre i wrapper App* invece dei widget Material puri per mantenere stile e token coerenti.
Per overlay (dialog, sheet, select) usa rootNavigator: true dove indicato per sovrapporsi all’app intera.

3) Componenti principali e pattern d’uso
AppButton (components/button.dart)
Varianti: default, destructive, outline, secondary, ghost, link.
Taglie: default, sm, lg, icon, iconSm, iconLg.
Props chiave: label, leading, trailing, isInvalid, enabled, onPressed.
Esempio:
AppButton(
  variant: AppButtonVariant.secondary,
  size: AppButtonSize.sm,
  leading: Icon(Icons.add),
  label: 'Nuovo',
  onPressed: () {},
)
AppInput (components/input.dart)
Vertical padding = 0 con StrutStyle per allineamento verticale del testo (come shadcn).
Supporta placeholder e stati invalid.
Pattern con Label:
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    AppLabel(child: Text('Email')),
    SizedBox(height: 8),
    AppInput(hintText: 'name@azienda.com'),
  ],
)
AppSelect (components/select.dart)
Raggruppa elementi, overlay con animazioni, tastiera (↑/↓, Enter, Esc), allineamento top-right.
Props: groups, value, placeholder, enabled, isInvalid, onChanged.
Esempio:
AppSelect(
  groups: [
    SelectGroupData(
      label: 'Team',
      items: [SelectItemData(value: 'aa', label: 'Alpha')],
    ),
  ],
  placeholder: 'Seleziona',
  onChanged: (v) {},
)
Checkbox / RadioGroup / Switch
Mantieni la Label vicino al controllo; usa isInvalid per focus ring rosso sui componenti che lo prevedono.
Esempi:
AppCheckbox(value: true, onChanged: (v) {});
AppRadioGroup(
  options: [AppRadioOption(value: 'a', label: 'A')],
  value: 'a',
  onChanged: (v) {},
);
AppSwitch(value: true, onChanged: (v) {});
Tooltip (components/tooltip.dart)
Wrappa il trigger e mostra un contenuto testuale breve.
AppTooltip(message: 'Suggerimento', child: AppButton(label: 'Info'));
Dialog (components/dialog.dart)
Usa AppDialog.show con builder che ritorna AppDialogContent.
AppDialog.show(
  context: context,
  builder: (ctx) => AppDialogContent(children: [
    const AppDialogHeader(children: [
      AppDialogTitle('Titolo'),
      AppDialogDescription('Descrizione')
    ]),
    const Text('Corpo del dialog'),
    AppDialogFooter(children: [
      AppButton(
        label: 'Conferma',
        onPressed: () => Navigator.of(ctx).pop(),
      ),
      AppButton(
        variant: AppButtonVariant.secondary,
        label: 'Annulla',
        onPressed: () => Navigator.of(ctx).pop(),
      ),
    ])
  ]),
);
Sheet (components/sheet.dart)
Usa showSheet(context) con Navigator.of(context, rootNavigator: true).push per overlay globale.
Sonner (components/sonner.dart)
Monta AppToaster in MaterialApp.builder.
Helper:
toastSuccess(context, 'Titolo', description: 'Dettagli');
toastInfo(context, 'Info utile');
toastError(context, 'Errore imprevisto');
toastLoading(context, 'Elaborazione…');
Per aggiornare un loading, mostra success/error successivo con lo stesso toastId.
Altri componenti principali
Tabs, Pagination, Separator, Card, Badge, Avatar, Skeleton, Spinner, Breadcrumb, Alert.
Esempi:
AppTabs(tabs: ['Profilo','Team'], onChanged: (i) {});
AppPagination(page: 1, totalPages: 10, onChanged: (p) {});
AppSeparator();
AppCard(child: Column(children: [Text('Titolo'), Text('Contenuto')]));
AppBadge(label: 'Beta');
AppAvatar(initials: 'FS');

4) Pattern form consigliati
Sempre Label sopra al campo, helper o error sotto.
Stati: enabled, disabled, invalid (bordo/ring), focus visibile.
Composizione con InputGroup per icone leading/trailing.
Feedback: usa Sonner per success/error e Dialog per conferme.


5) Theming e token
GlobalTheme: genera ColorScheme neutrale coerente con shadcn.
DefaultTheme.apply: aggiunge DefaultTokens (ring, radii, spacing, charts) e tipografia.
Override brand: deriva ThemeData da ColorScheme.fromSeed, poi applica DefaultTheme.apply.
Accesso rapido ai token:
final gt = Theme.of(context).extension<GlobalTokens>();
final dt = Theme.of(context).extension<DefaultTokens>();

6) Accessibilità e UX
Focus ring sempre visibile sui componenti interattivi.
Tastiera: Select supporta navigazione; Dialog/Sheet hanno barrierDismissible.
Contrasto: sfrutta i neutrals di GlobalTokens; usa isInvalid per evitare confusione cromatica con lo stato.

7) Componenti mancanti e fallback temporanei
Mancano:
Accordion, Popover, Dropdown/Menu/Menubar, Drawer/Sidebar, Table, Progress, Slider, Calendar/DatePicker, HoverCard, ContextMenu, Toggle/ToggleGroup, ScrollArea, Resizable, InputOTP, NativeSelect, NavigationMenu, Carousel, AspectRatio, Collapsible, Empty, Field/Form, Item, Kbd.
Fallback:
Table → usa DataTable + wrapper (bordo, zebra, densità).
Dropdown/Popover → PopupMenuButton o AppSelect.
Sidebar/Drawer → NavigationRail + colori DefaultTokens.sidebarPrimary.
Progress/Slider/Calendar → widget Material con stile token.
Accordion/Collapsible → ExpansionPanelList.

8) Best practice di composizione
Mantieni overlay con rootNavigator: true.
Evita const dove i widget DS non hanno costruttori const.
Allinea verticalmente testo negli input (StrutStyle già gestito).
Usa SizedBox(height: 8) come gap standard tra Label e campo.

9) Testing e qualità
Verifica focus/hover/press degli stati.
Testa light/dark e overlay.
Usa hot reload per iterare sulle demo (tokens_test_page.dart).

10) FAQ
Come mostro un toast di successo?
toastSuccess(context, 'Salvato', description: 'Impostazioni aggiornate')
Come apro un dialog?
Vedi esempio in sezione Dialog con AppDialog.show.
Come applico un tema brand?
Deriva ColorScheme, crea ThemeData, poi DefaultTheme.apply e monta GlobalTokens.

11) Chart (Bar) — Guida completa (shadcn/ui → Flutter)
I componenti chart (attualmente solo Bar) riproducono le varianti Recharts di shadcn/ui, con coerenza visiva e tipografica rispetto al resto del design system.

11.1 Setup
Aggiungi nel pubspec.yaml:
fl_chart: ^0.68.0
Importa la variante necessaria:
import 'components/charts/bar/chart_bar_default.dart';
import 'components/charts/bar/chart_bar_horizontal.dart';
import 'components/charts/bar/chart_bar_multiple.dart';
import 'components/charts/bar/chart_bar_stacked.dart';
import 'components/charts/bar/chart_bar_active.dart';
import 'components/charts/bar/chart_bar_interactive.dart';

11.2 Struttura
Tutti i Bar chart si basano su shared/bar_base.dart, che gestisce:
grid, axis, padding, tooltip testuale,
compatibilità con fl_chart 0.68.x,
accesso ai colori tramite ChartColors.
I dataset di esempio sono in shared/bar_datasets.dart.

11.3 Colori e token
ChartColors definisce palette e varianti (chart1–chart5, desktop, mobile, browser, grid, ecc.).
Puoi:
usare ChartColors.fallback(context) per una palette coerente col tema, oppure
creare un adapter dai tuoi token (GlobalTokens/DefaultTokens).

11.4 Varianti principali
Variante	Descrizione	File
Default	Una serie (Desktop)	chart_bar_default.dart
Horizontal	Barre orizzontali	chart_bar_horizontal.dart
Multiple	Due serie affiancate (Desktop/Mobile)	chart_bar_multiple.dart
Stacked	Due serie impilate + legenda	chart_bar_stacked.dart
Active	Evidenzia una barra selezionata	chart_bar_active.dart
Interactive	Toggle Desktop/Mobile con totali	chart_bar_interactive.dart

11.5 Esempi d’uso
Default
ChartBarDefault(colors: ChartColors.fallback(context))
Horizontal
ChartBarHorizontal(colors: ChartColors.fallback(context))
Multiple
ChartBarMultiple(colors: ChartColors.fallback(context))
Stacked
ChartBarStacked(colors: ChartColors.fallback(context))
Active
ChartBarActive(activeIndex: 2, colors: ChartColors.fallback(context))
Interactive
ChartBarInteractive(colors: ChartColors.fallback(context))

11.6 Tooltip
Tutti i chart usano un tooltip testuale compatibile con fl_chart 0.68.x, definito in BarChartBase:
tooltipPayloadBuilder: (context, group, groupIndex, rod, rodIndex, colors) {
  final i = group.x.toInt();
  return BarTooltipPayload(
    title: month3(barDataMonthly[i]['month'] as String),
    items: [(colors.colorDesktop, 'Desktop', rod.toY.toInt().toString())],
  );
}
Per un tooltip card stile shadcn, puoi aggiungere una overlay custom con touchCallback.

11.7 Styling coerente con shadcn/ui
Radius: 8 default, 5 horizontal, 4 multiple/stacked.
Stroke barra attiva: 2px.
Opacity → usa .withValues(alpha: x) (no withOpacity).
Grid: orizzontale (default/multiple/stacked), verticale (horizontal).
Legend: opzionale (Stacked).
Card container: ChartContainer (background, border, radius 12).

11.8 Pattern composizione in card
AppCard(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Bar Chart', style: Theme.of(context).textTheme.titleMedium),
      Text('January – June 2024',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).textTheme.bodySmall!.color!.withValues(alpha: 0.7),
          )),
      const SizedBox(height: 16),
      ChartBarDefault(colors: ChartColors.fallback(context)),
      const SizedBox(height: 12),
      Text('Showing total visitors for the last 6 months',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).textTheme.bodySmall!.color!.withValues(alpha: 0.7),
          )),
    ],
  ),
)

11.9 Accessibilità e performance
Colori chartX e colorDesktop/Mobile devono garantire contrasto su cardBg.
Tooltip usa tabular figures per valori allineati.
alignment: BarChartAlignment.spaceBetween ottimizza la densità.
Usa interval su SideTitles per label più pulite.

11.10 Troubleshooting
Errore	Soluzione
tooltipBuilder isn’t defined	Usa tooltipPayloadBuilder
withOpacity deprecated	Usa .withValues(alpha: …)
borderRadius isn’t defined on BarChartRodStackItem	Rimuovilo (non supportato in 0.68.x)
curly_braces_in_flow_control_structures	Aggiungi graffe negli early return

11.11 Checklist finale
 fl_chart: ^0.68.0 installato
 Nessun .withOpacity()
 Nessun tooltipBuilder obsoleto
 Early return con graffe
 Token coerenti da GlobalTheme
 Light/Dark funzionanti