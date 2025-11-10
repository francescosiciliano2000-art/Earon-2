// Implementazione Web: stampa tramite window.print().
// Nota: questo file è incluso solo quando dart.library.html è disponibile.

import 'dart:html' as html;

Future<void> agendaPrintWeb() async {
  // Semplicemente invoca la stampa del browser.
  html.window.print();
}

// Su Web, la generazione PDF non è necessaria qui: per compatibilità
// esponiamo comunque la funzione ma deleghiamo a window.print.
Future<void> agendaPrintPdf(String title, List<Map<String, String>> rows) async {
  html.window.print();
}