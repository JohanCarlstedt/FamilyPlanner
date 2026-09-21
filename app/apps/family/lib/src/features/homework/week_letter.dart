import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// The text of a week letter, whatever form it arrived in.
///
/// School letters come as a Word document on SharePoint or in Teams, as a
/// PDF, or as text someone copied. The document itself usually cannot be
/// fetched: a SharePoint link answers 401 to anyone outside the school's
/// tenant, and no family app is getting an app registration in a
/// municipality's Entra directory. So the letter arrives the way the family
/// already has it — shared from the app that is already signed in, or
/// pasted — and this turns it into text for the reader in domain.
class WeekLetter {
  WeekLetter._();

  /// Hosts whose documents need a sign-in we do not have: a school's
  /// SharePoint or OneDrive, a shared Google Doc.
  ///
  /// Sharing the *link* to one of these is the obvious thing to try, and it
  /// cannot work — the link answers 401 to anyone outside the tenant. It is
  /// worth recognising so the app can say that, rather than trying to read
  /// it as a recipe and failing with something irrelevant.
  static bool looksLikeDocument(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    const hosts = [
      'sharepoint.com',
      'onedrive.live.com',
      '1drv.ms',
      'docs.google.com',
      'drive.google.com',
    ];
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }

  /// Fetches a shared document and returns its bytes, or null.
  ///
  /// A SharePoint "anyone with the link" address does serve the file
  /// without a login — but only to something that looks like a browser.
  /// With curl's own user agent it answers 401, which is what made this
  /// look impossible at first. The share token in the link becomes a
  /// download address that hands back the .docx directly.
  ///
  /// Fetched on the phone, like every other import here, so the family's
  /// server never sees the school's address.
  static Future<List<int>?> fetch(String url, {http.Client? client}) async {
    final target = downloadUrl(url) ?? Uri.tryParse(url);
    if (target == null) return null;
    final web = client ?? http.Client();
    try {
      final response = await web.get(
        target,
        // SharePoint serves a document to a browser and refuses a script.
        headers: const {
          'user-agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 '
              'Safari/537.36',
        },
      );
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } on Object {
      return null;
    } finally {
      if (client == null) web.close();
    }
  }

  /// The address that hands back the file itself, for the sharing links
  /// that have one.
  ///
  /// SharePoint and OneDrive: `/:w:/g/personal/<user>/<token>` becomes
  /// `/personal/<user>/_layouts/15/download.aspx?share=<token>`.
  static Uri? downloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (!looksLikeDocument(url)) return null;
    final parts = uri.pathSegments;
    // :w: | g | personal | <user> | <token>
    final personal = parts.indexOf('personal');
    if (personal >= 0 && parts.length > personal + 2) {
      final user = parts[personal + 1];
      final token = parts[personal + 2];
      return uri.replace(
        path: '/personal/$user/_layouts/15/download.aspx',
        queryParameters: {'share': token},
      );
    }
    return null;
  }

  /// Pulls the words out of [file], or null when it is not a kind we read.
  static Future<String?> textOf(File file) async {
    final name = file.path.toLowerCase();
    if (name.endsWith('.txt') || name.endsWith('.md')) {
      return file.readAsString();
    }
    if (name.endsWith('.docx')) return _fromDocx(await file.readAsBytes());
    if (_pictures.any(name.endsWith)) return textOfPhoto(file);
    return null;
  }

  static const _pictures = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];

  /// The words in a photograph of the whiteboard — which the spec calls
  /// the only entry flow that survives contact with a Tuesday evening,
  /// because children do not type homework into apps.
  ///
  /// Recognition happens on the phone: ML Kit's text model runs locally,
  /// so the picture of a classroom whiteboard — other children's names and
  /// all — is never uploaded anywhere, and the family's own server could
  /// not read it either.
  static Future<String?> textOfPhoto(File file) async {
    final recognizer = TextRecognizer();
    try {
      final read = await recognizer.processImage(InputImage.fromFile(file));
      final text = read.text.trim();
      return text.isEmpty ? null : text;
    } on Object {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  /// The tables in a .docx, as rows of cell text.
  ///
  /// A school's week overview is a table, not prose: weekday columns, a row
  /// per class, homework in the cells. Flattening it to lines loses which
  /// day a cell belonged to, which is most of what the document says.
  static List<List<List<String>>> tablesIn(List<int> bytes) {
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final document = zip.files.where((f) => f.name == 'word/document.xml');
      if (document.isEmpty) return const [];
      final xml = _text(document.first.content as List<int>);
      return [
        for (final table in RegExp(
          r'<w:tbl>.*?</w:tbl>',
          dotAll: true,
        ).allMatches(xml))
          [
            for (final row in RegExp(
              r'<w:tr[ >].*?</w:tr>',
              dotAll: true,
            ).allMatches(table.group(0)!))
              [
                for (final cell in RegExp(
                  r'<w:tc>.*?</w:tc>',
                  dotAll: true,
                ).allMatches(row.group(0)!))
                  _stripTags(
                    cell.group(0)!.replaceAll('</w:p>', ' '),
                  ).replaceAll(RegExp(r'\s+'), ' ').trim(),
              ],
          ],
      ];
    } on Object {
      return const [];
    }
  }

  /// The words in a document already in memory, for one that was fetched
  /// rather than shared as a file.
  static String? textOfBytes(List<int> bytes) => _fromDocx(bytes);

  /// A .docx is a zip with the text in word/document.xml. Reading it
  /// directly avoids a Word-format dependency for what is, in the end, one
  /// XML file with tags to strip.
  static String? _fromDocx(List<int> bytes) {
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final document = zip.files.where((f) => f.name == 'word/document.xml');
      if (document.isEmpty) return null;
      return _stripTags(_text(document.first.content as List<int>));
    } on Object {
      // A file that is not the zip it claims to be is not worth a crash on
      // the share sheet; the screen says it could not be read.
      return null;
    }
  }

  /// word/document.xml is UTF-8, as every .docx is.
  ///
  /// It was read a byte at a time, which is the same thing for English and
  /// nonsense for Swedish: "Läxa till måndag" arrived as "LÃ¤xa till
  /// mÃ¥ndag". Worse than ugly — the reader in domain matches weekdays and
  /// subjects by name, so "mÃ¥ndag" is not a Monday and a letter full of
  /// homework quietly read as empty.
  ///
  /// Malformed bytes are allowed through as the replacement character
  /// rather than thrown: one bad byte in a school's document should cost
  /// that character, not the week.
  ///
  /// The byte-order mark goes too. Word writes one — the real letter this
  /// was checked against begins with it — and `utf8.decode` keeps it as an
  /// invisible character at the start of the first line, where it is
  /// exactly the wrong side of a `^` or a word boundary.
  static String _text(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }

  /// Word's XML, as lines. Paragraph and line breaks become newlines,
  /// because the reader in domain works a line at a time and a letter
  /// flattened to one line loses every deadline.
  static String _stripTags(String xml) => _entities(
    xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAll(RegExp(r'<w:tab\s*/>'), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ''),
  ).split('\n').map((l) => l.trim()).join('\n');

  /// XML entities, in one left-to-right pass.
  ///
  /// One pass rather than a chain of replaceAll, so that an escaped escape
  /// survives: "&amp;lt;" is the text "&lt;", and replacing "&amp;" and
  /// then "&lt;" turns it into "<".
  ///
  /// Numeric forms are here because Word writes them sometimes — "&#228;"
  /// and "&#xE4;" are both ä — and a letter is no more readable with them
  /// left in than with the bytes mangled.
  static String _entities(String text) => text.replaceAllMapped(
    RegExp(r'&(#\d+|#[xX][0-9a-fA-F]+|amp|lt|gt|quot|apos);'),
    (m) {
      final name = m.group(1)!;
      if (name.startsWith('#')) {
        final hex = name[1] == 'x' || name[1] == 'X';
        final code = int.tryParse(
          hex ? name.substring(2) : name.substring(1),
          radix: hex ? 16 : 10,
        );
        // Outside Unicode, or a surrogate half: left as written rather
        // than turned into something that is not a character.
        if (code == null || code < 0 || code > 0x10FFFF) return m.group(0)!;
        return String.fromCharCode(code);
      }
      return const {
        'amp': '&',
        'lt': '<',
        'gt': '>',
        'quot': '"',
        'apos': "'",
      }[name]!;
    },
  );

  /// What [text] says about homework, for someone to confirm.
  static List<HomeworkCandidate> read(
    String text, {
    required String timeZone,
    DateTime? now,
  }) => readHomeworkLetter(
    text,
    now: now ?? DateTime.now().toUtc(),
    timeZone: timeZone,
  );
}
