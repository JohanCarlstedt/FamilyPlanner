import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:family/src/features/homework/week_letter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A .docx is a zip with the text in word/document.xml, written as UTF-8.
List<int> docx(String documentXml) {
  final archive = Archive();
  final bytes = utf8.encode(documentXml);
  archive.addFile(ArchiveFile('word/document.xml', bytes.length, bytes));
  return ZipEncoder().encode(archive);
}

String paragraph(String text) => '<w:p><w:r><w:t>$text</w:t></w:r></w:p>';

void main() {
  test('a school document link is recognised, not treated as a recipe', () {
    // The real one, from Härryda kommun's SharePoint.
    expect(
      WeekLetter.looksLikeDocument(
        'https://harrydakommun-my.sharepoint.com/:w:/g/personal/'
        'linus_rydberg_harryda_se/IQAs-7VY9xh3SZyOF3FgX831AQ',
      ),
      isTrue,
    );
    expect(
      WeekLetter.looksLikeDocument('https://docs.google.com/document/d/abc'),
      isTrue,
    );
    expect(WeekLetter.looksLikeDocument('https://1drv.ms/w/s!Abc'), isTrue);
  });

  test('a recipe link still goes to the recipe importer', () {
    expect(WeekLetter.looksLikeDocument('https://www.ica.se/recept/pasta/'), isFalse);
    expect(WeekLetter.looksLikeDocument('https://arla.se/recept/pannkakor'), isFalse);
  });

  test('a host merely containing the words is not one of them', () {
    // sharepoint.com.example.com is not SharePoint.
    expect(
      WeekLetter.looksLikeDocument('https://sharepoint.com.evil.example/x'),
      isFalse,
    );
    expect(WeekLetter.looksLikeDocument('not a url at all'), isFalse);
  });

  test('a SharePoint share link becomes the address that serves the file', () {
    final url = WeekLetter.downloadUrl(
      'https://harrydakommun-my.sharepoint.com/:w:/g/personal/'
      'linus_rydberg_harryda_se/IQAs-7VY9xh3SZyOF3FgX831AQ?rtime=KDS2w1gX30g',
    );

    expect(url, isNotNull);
    expect(url!.host, 'harrydakommun-my.sharepoint.com');
    expect(
      url.path,
      '/personal/linus_rydberg_harryda_se/_layouts/15/download.aspx',
    );
    // The share token, which is what makes it readable without a login.
    expect(url.queryParameters['share'], 'IQAs-7VY9xh3SZyOF3FgX831AQ');
  });

  test('a link that is not a shared document has no download address', () {
    expect(WeekLetter.downloadUrl('https://www.ica.se/recept/pasta/'), isNull);
    expect(WeekLetter.downloadUrl('nonsense'), isNull);
  });

  group('Swedish survives the trip out of Word', () {
    // Word writes UTF-8. Reading it a byte at a time turns "Läsa" into
    // "LÃ¤sa" — which then fails to match a weekday or a subject either,
    // so a letter full of homework quietly reads as empty.
    const swedish = 'Läxa till måndag: läs sidan 24. Prov på fredag. '
        'Öva glosor, kom ihåg idrottskläder.';

    test('a paragraph keeps its å, ä and ö', () {
      final text = WeekLetter.textOfBytes(
        docx('<w:document><w:body>${paragraph(swedish)}</w:body></w:document>'),
      );

      expect(text, contains('Läxa till måndag'));
      expect(text, contains('läs sidan 24'));
      expect(text, contains('Öva glosor'));
      expect(text, contains('idrottskläder'));
      expect(text, isNot(contains('Ã')));
    });

    test('so does a table cell, which is how a week plan arrives', () {
      final tables = WeekLetter.tablesIn(
        docx(
          '<w:document><w:body><w:tbl>'
          '<w:tr><w:tc>${paragraph("Måndag")}</w:tc>'
          '<w:tc>${paragraph("Fredag")}</w:tc></w:tr>'
          '<w:tr><w:tc>${paragraph("5A")}</w:tc>'
          '<w:tc>${paragraph("Sv: läsförståelse")}</w:tc></w:tr>'
          '</w:tbl></w:body></w:document>',
        ),
      );

      expect(tables, hasLength(1));
      expect(tables.first.first, ['Måndag', 'Fredag']);
      expect(tables.first[1], ['5A', 'Sv: läsförståelse']);
    });

    test('a character written as an XML entity arrives as itself', () {
      // Word usually writes the letter directly, but not always.
      final text = WeekLetter.textOfBytes(
        docx(
          '<w:document><w:body>'
          '${paragraph("L&#228;sa &amp; r&#xE4;kna")}'
          '</w:body></w:document>',
        ),
      );

      expect(text, contains('Läsa & räkna'));
    });

    test('the byte-order mark Word writes does not reach the reader', () {
      final xml =
          '<?xml version="1.0" encoding="utf-8"?>'
          '<w:document><w:body>${paragraph("Veckoöversikt årskurs 5")}'
          '</w:body></w:document>';
      final withBom = [0xEF, 0xBB, 0xBF, ...utf8.encode(xml)];
      final archive = Archive()
        ..addFile(
          ArchiveFile('word/document.xml', withBom.length, withBom),
        );

      final text = WeekLetter.textOfBytes(ZipEncoder().encode(archive));

      expect(text, isNotNull);
      expect(text!.startsWith('Veckoöversikt'), isTrue, reason: text);
      expect(text.contains('\uFEFF'), isFalse);
    });

    test('a byte that is not valid UTF-8 costs that character, not the file', () {
      final archive = Archive();
      final broken = [
        ...utf8.encode('<w:document><w:body><w:p><w:r><w:t>L'),
        0xE4, // ä in latin-1: not valid UTF-8 on its own
        ...utf8.encode('sa sidan 24</w:t></w:r></w:p></w:body></w:document>'),
      ];
      archive.addFile(
        ArchiveFile('word/document.xml', broken.length, broken),
      );

      final text = WeekLetter.textOfBytes(ZipEncoder().encode(archive));

      expect(text, isNotNull);
      expect(text, contains('sa sidan 24'));
    });
  });
}
