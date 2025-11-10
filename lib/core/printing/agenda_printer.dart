// Abstraction per stampa Agenda con import condizionale.
// Su Web: usa window.print() per stampare la pagina corrente.
// Su macOS/Windows/Linux: genera un PDF e apre la dialog di stampa.

// Import condizionale: se siamo su Web (dart.library.html) usa la compat web,
// altrimenti usa l'implementazione desktop/IO.
import 'agenda_printer_io.dart' if (dart.library.html) 'agenda_printer_web_compat.dart' as impl;

// Gli export devono apparire prima di ogni dichiarazione.
export 'agenda_printer_io.dart'
  if (dart.library.html) 'agenda_printer_web_compat.dart';

/// Stampa via browser (solo Web). Su piattaforme non-Web è no-op.
Future<void> agendaPrintWeb() async {
  await impl.agendaPrintWeb();
}

/// Genera un PDF e apre la dialog di stampa nativa (macOS/Windows/Linux).
/// Accetta righe già "risolte" in stringhe pronte per il PDF.
Future<void> agendaPrintPdf(String title, List<Map<String, String>> rows) async {
  await impl.agendaPrintPdf(title, rows);
}

