// Abstraction per stampa Agenda con import condizionale.
// Su Web: usa window.print() per stampare la pagina corrente.
// Su macOS/Windows/Linux: genera un PDF e apre la dialog di stampa.

// Import condizionale robusto:
// - Se dart.library.io è disponibile → usa implementazione desktop (PDF)
// - Altrimenti (Web) → usa implementazione web (window.print)
import 'agenda_printer_web.dart' if (dart.library.io) 'agenda_printer_io.dart' as impl;

/// Stampa via browser (solo Web). Su piattaforme non-Web è no-op.
Future<void> agendaPrintWeb() async {
  await impl.agendaPrintWeb();
}

/// Genera un PDF e apre la dialog di stampa nativa (macOS/Windows/Linux).
/// Accetta righe già "risolte" in stringhe pronte per il PDF.
Future<void> agendaPrintPdf(String title, List<Map<String, String>> rows) async {
  await impl.agendaPrintPdf(title, rows);
}