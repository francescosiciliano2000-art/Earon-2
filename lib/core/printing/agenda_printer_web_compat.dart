import 'package:web/web.dart' as web;

// Implementazione Web: usa window.print() o data URL per aprire il contenuto.
// Nota: Evitiamo l'uso diretto di Blob con tipi JS (JSArray<BlobPart>, BlobPropertyBag)
// per compatibilità, usando una data URL che il browser può aprire/stampare.

/// Stampa la pagina corrente (tipico su Web)
Future<void> agendaPrintWeb() async {
  web.window.print();
}

/// Su Web non generiamo PDF nativo; facciamo no-op oppure potremmo
/// generare un download di testo. Manteniamo no-op per compatibilità.
Future<void> agendaPrintPdf(String title, List<Map<String, String>> rows) async {
  // No-op su Web: la generazione PDF è gestita nelle piattaforme desktop.
}

/// Esempio di apertura contenuto come data URL in una nuova tab (non usato direttamente).
class AgendaPrinter {
  Future<void> printAgenda(List<Map<String, dynamic>> rows) async {
    final text = rows.map((e) => e.toString()).join('\n');
    final url = 'data:text/plain;charset=utf-8,' + Uri.encodeComponent(text);
    web.window.open(url, '_blank');
  }
}
