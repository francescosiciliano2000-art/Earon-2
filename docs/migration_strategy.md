# Strategia di Migrazione al Nuovo Design System

## Stato Attuale
✅ **Completato:**
- Analisi struttura design system
- Correzione errori nei componenti charts
- Correzione import semplici (app_icons.dart)
- Test funzionalità base dell'app

## Componenti Disponibili nel Design System
- `AppButton` (con variant: default_, destructive, outline, secondary, ghost, link)
- `AppCard` (con header, content, footer)
- `AppInput` (sostituto di AppTextField)
- `AppSelect`
- `AppCheckbox`
- `AppRadioGroup`
- `AppSwitch`
- `AppDialog`
- `AppSheet`
- `AppDataTable`
- `AppPagination`
- `AppBadge`
- `AppAvatar`
- `AppTabs`
- `AppTooltip`
- `AppSeparator`
- `AppSkeleton`
- `AppSpinner`
- `AppAlert`
- `AppBreadcrumb`
- `DatePicker`
- `TopBar`
- `Sonner` (toast system)

## Mappatura Componenti Vecchi → Nuovi

### Bottoni
```dart
// VECCHIO
AppButton.primary(onPressed: () {}, child: Text('Click'))
AppButton.secondary(onPressed: () {}, child: Text('Click'))
AppButton.ghost(onPressed: () {}, child: Text('Click'))

// NUOVO
AppButton(variant: AppButtonVariant.default_, onPressed: () {}, child: Text('Click'))
AppButton(variant: AppButtonVariant.secondary, onPressed: () {}, child: Text('Click'))
AppButton(variant: AppButtonVariant.ghost, onPressed: () {}, child: Text('Click'))
```

### Input
```dart
// VECCHIO
AppTextField(controller: controller, label: 'Nome')
AppTextFormField(controller: controller, labelText: 'Nome')

// NUOVO
AppInput(controller: controller, placeholder: 'Nome')
// + AppLabel('Nome') se serve label separata
```

### Toast
```dart
// VECCHIO
AppToast.show(context, 'Messaggio', type: ToastType.success)

// NUOVO
toast('Messaggio') // usando Sonner
```

### Spacing
```dart
// VECCHIO
AppSpacing.xs, AppSpacing.s, AppSpacing.sm, AppSpacing.md

// NUOVO
8.0, 16.0, 16.0, 24.0 (valori hardcoded)
```

### Tokens/Theme
```dart
// VECCHIO
AppTokens, AppRadii

// NUOVO
GlobalTokens, DefaultTokens, ShadcnRadii
Theme.of(context).extension<GlobalTokens>()
Theme.of(context).extension<DefaultTokens>()
```

## Piano di Migrazione per File Complessi

### Fase 1: File con Pochi Componenti (1-3 componenti)
- `hearings_page.dart` ✅ (già fatto)
- `merge_dialog.dart` (solo AppButton)
- `change_client_dialog.dart` (AppButton + AppInput)

### Fase 2: File con Componenti Medi (4-8 componenti)
- `task_edit_dialog.dart`
- `hearing_create_dialog.dart`
- `matter_create_sheet.dart`

### Fase 3: File Complessi (8+ componenti)
- `ui_test_page.dart`
- `clienti_page.dart`
- `matters_list_page.dart`

## Strategia per Ogni File

1. **Backup**: Creare copia del file originale se necessario
2. **Import**: Aggiornare tutti gli import ai nuovi percorsi
3. **Componenti**: Sostituire uno alla volta seguendo la mappatura
4. **Tokens**: Sostituire AppTokens/AppRadii con GlobalTokens/DefaultTokens
5. **Spacing**: Sostituire AppSpacing con valori numerici
6. **Test**: Verificare che il file compili e funzioni
7. **Refine**: Ottimizzare il codice se necessario

## Componenti Mancanti da Creare
Se durante la migrazione troviamo componenti non disponibili:
- `AppFieldError` → Usare Text con colore error
- `AppToast` → Usare Sonner
- `AppChips` → Usare AppBadge o creare se necessario
- `MetricCard` → Usare AppCard con layout personalizzato

## Note Importanti
- Non modificare la struttura del design system esistente
- Mantenere la compatibilità con il database Supabase
- Testare ogni file dopo la migrazione
- Documentare eventuali problemi o limitazioni trovate