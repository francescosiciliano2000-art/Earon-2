// Implementazione Desktop/IO: genera PDF e apre il dialog di stampa.
// Questo file viene usato quando dart.library.html NON è disponibile.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> agendaPrintWeb() async {
  // Su piattaforme non-Web non facciamo nulla.
}

Future<void> agendaPrintPdf(String title, List<Map<String, String>> rows) async {
  // Carica font Google per garantire copertura dei glifi (es. U+2014 em dash)
  final baseFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();
  final italicFont = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      italic: italicFont,
    ),
  );

  pw.Widget buildHeader() => pw.Center(
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, font: boldFont),
          textAlign: pw.TextAlign.center,
        ),
      );

  // Header della tabella
  final tableHeaders = <String>['Tipo', 'Titolo', 'Scadenza', 'Pratica', 'Assegnatario'];

  // Costruiamo le righe della tabella con eventuale line-through per completati
  List<pw.TableRow> buildTableRows() {
    final headerStyle = pw.TextStyle(font: boldFont, fontSize: 12);
    final bodyStyle = pw.TextStyle(font: baseFont, fontSize: 11);

    final children = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: tableHeaders
            .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: pw.Text(h, style: headerStyle),
                ))
            .toList(),
      )
    ];

    for (final r in rows) {
      final done = (r['done'] ?? 'false').toLowerCase() == 'true';
      final style = done
          ? pw.TextStyle(font: baseFont, fontSize: 11, decoration: pw.TextDecoration.lineThrough)
          : bodyStyle;
      children.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: pw.Text(r['type'] ?? '', style: style),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: pw.Text(r['title'] ?? '', style: style),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: pw.Text(r['due'] ?? '', style: style),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: pw.Text(r['matter'] ?? '', style: style),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: pw.Text(r['assignee'] ?? '', style: style),
            ),
          ],
        ),
      );
    }
    return children;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      build: (context) => [
        buildHeader(),
        pw.SizedBox(height: 12),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5), children: buildTableRows()),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => doc.save());
}

class AgendaPrinter {
  Future<void> printAgenda(List<Map<String, dynamic>> rows) async {
    // TODO: implementazione desktop (es. package:printing/pdf) già presente altrove.
    // Placeholder per separare le piattaforme.
  }
}
