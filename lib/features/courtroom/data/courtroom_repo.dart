// lib/features/courtroom/data/courtroom_repo.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../design system/components/combobox.dart';

/// Repository per caricare e osservare l'elenco dei tribunali/fori raggruppati per regione
/// dal file JSON fornito. Il file è gestito come asset per funzionare su Web/Desktop/Mobile.
class CourtroomRepo {
  /// Path dell'asset dichiarato in pubspec.yaml
  static const String assetPath = 'lib/features/courtroom.json';

  /// Carica le opzioni raggruppate per regione dall'asset.
  Future<List<ComboboxGroupData>> loadGroups() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final data = json.decode(raw) as Map<String, dynamic>;
      final List<ComboboxGroupData> groups = [];
      for (final entry in data.entries) {
        final region = entry.key.trim();
        final list = List<String>.from(entry.value as List);
        list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        groups.add(
          ComboboxGroupData(
            label: region,
            items: list.map((s) => ComboboxItem(value: s, label: s)).toList(),
          ),
        );
      }
      // Ordina regioni alfabeticamente
      groups.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      return groups;
    } catch (_) {
      // In caso di errore (asset non trovato) ritorna lista vuota
      return const [];
    }
  }

  /// Osserva i gruppi e produce stream con aggiornamenti.
  /// In debug esegue un leggero polling dell'asset per cogliere eventuali modifiche
  /// durante lo sviluppo (hot restart). In release emette solo una volta.
  Stream<List<ComboboxGroupData>> watchGroups() {
    final controller = StreamController<List<ComboboxGroupData>>();
    Timer? timer;
    String? lastFingerprint;

    String fingerprint(List<ComboboxGroupData> groups) {
      return groups
          .map((g) => '${g.label.toLowerCase()}|${g.items.map((i) => i.label.toLowerCase()).join(',')}')
          .join('||');
    }

    Future<void> emit() async {
      final groups = await loadGroups();
      final fp = fingerprint(groups);
      if (lastFingerprint != fp) {
        lastFingerprint = fp;
        controller.add(groups);
      }
    }

    controller.onListen = () {
      emit();
      if (kDebugMode) {
        timer = Timer.periodic(const Duration(seconds: 2), (_) => emit());
      }
    };
    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };
    return controller.stream;
  }
}