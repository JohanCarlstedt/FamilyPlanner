import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/domain.dart';

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

  /// Pulls the words out of [file], or null when it is not a kind we read.
  static Future<String?> textOf(File file) async {
    final name = file.path.toLowerCase();
    if (name.endsWith('.txt') || name.endsWith('.md')) {
      return file.readAsString();
    }
    if (name.endsWith('.docx')) return _fromDocx(await file.readAsBytes());
    return null;
  }

  /// A .docx is a zip with the text in word/document.xml. Reading it
  /// directly avoids a Word-format dependency for what is, in the end, one
  /// XML file with tags to strip.
  static String? _fromDocx(List<int> bytes) {
    try {
      final zip = ZipDecoder().decodeBytes(bytes);
      final document = zip.files.where((f) => f.name == 'word/document.xml');
      if (document.isEmpty) return null;
      final xml = String.fromCharCodes(
        document.first.content as List<int>,
      );
      return _stripTags(xml);
    } on Object {
      // A file that is not the zip it claims to be is not worth a crash on
      // the share sheet; the screen says it could not be read.
      return null;
    }
  }

  /// Word's XML, as lines. Paragraph and line breaks become newlines,
  /// because the reader in domain works a line at a time and a letter
  /// flattened to one line loses every deadline.
  static String _stripTags(String xml) => xml
      .replaceAll(RegExp(r'</w:p>'), '\n')
      .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
      .replaceAll(RegExp(r'<w:tab\s*/>'), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .split('\n')
      .map((l) => l.trim())
      .join('\n');

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
