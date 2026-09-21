import 'dart:io';

import 'package:archive/archive.dart';
import 'package:domain/domain.dart';
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
