import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'icon.dart';

/// Renders every launcher icon from tool/icon.dart.
///
///   flutter test tool/make_icons.dart
///
/// It runs under the test runner because that is what gives a Dart file a
/// working Flutter engine to rasterise with — this machine has no
/// rsvg-convert, ImageMagick or Inkscape, and adding one to draw four
/// rectangles would be a strange dependency to take on. Committed output,
/// run by hand when the icon changes.
void main() {
  // Not Platform.script: under `flutter test` that is the runner's own
  // generated entry point in a temporary directory, and the first run of
  // this wrote every icon into it. The test runner's working directory is
  // the package.
  final app = Directory.current.path;

  test('every icon this app ships', () async {
    // The test engine ships no real font: text drawn without this comes out
    // as filled rectangles, which is exactly what the first feature graphic
    // was. macOS has Helvetica; the graphic is the only thing that needs it.
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (font.existsSync()) {
      final data = await font.readAsBytes();
      await ui.loadFontFromList(data, fontFamily: 'IconText');
    }
    // iOS: the sizes its asset catalogue already names, so Contents.json
    // stays as it is. The 1024 is what the App Store shows.
    const ios = <String, double>{
      'Icon-App-1024x1024@1x.png': 1024,
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
    };
    for (final entry in ios.entries) {
      await _write(
        p.join(app, 'ios/Runner/Assets.xcassets/AppIcon.appiconset', entry.key),
        entry.value,
      );
    }

    // Android, the old way: one square per density, masked by the launcher.
    const densities = <String, double>{
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final entry in densities.entries) {
      await _write(
        p.join(app, 'android/app/src/main/res', entry.key, 'ic_launcher.png'),
        entry.value,
      );
    }

    // Android 8 and later: the launcher composes a background and a
    // foreground, and crops both to whatever shape it likes. The foreground
    // is 108dp of which only the middle 72 is safe, hence the scale.
    for (final entry in densities.entries) {
      await _write(
        p.join(
          app,
          'android/app/src/main/res',
          entry.key,
          'ic_launcher_foreground.png',
        ),
        entry.value * 108 / 48,
        background: false,
        contentScale: 72 / 108,
      );
    }

    // Something to look at without installing anything.
    await _write(p.join(app, 'tool/icon-preview.png'), 512);

    // Google Play's listing wants its own two: the icon at exactly 512, and
    // a 1024x500 banner shown at the top of the page (docs/play-store.md).
    await _write(p.join(app, 'tool/play/icon-512.png'), 512);
    await _writeFeatureGraphic(p.join(app, 'tool/play/feature-1024x500.png'));
  });
}

/// Play's feature graphic: the icon's bars beside the app's name, on the
/// same background, so the listing and the home screen look like the same
/// thing.
Future<void> _writeFeatureGraphic(String path) async {
  const width = 1024.0;
  const height = 500.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, width, height),
    ui.Paint()..color = iconBackground,
  );

  // The art is square. Drawn at full height it runs under the words, so it
  // is inset and the text starts clear of it.
  const art = 380.0;
  const artLeft = 80.0;
  canvas.save();
  canvas.translate(artLeft, (height - art) / 2);
  paintIcon(canvas, art, background: false);
  canvas.restore();

  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(
        fontFamily: 'IconText',
        fontSize: 82,
        fontWeight: ui.FontWeight.w600,
        textAlign: ui.TextAlign.left,
      ))
        ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
        ..addText('Family Planner');
  const textLeft = artLeft + art + 60;
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: width - textLeft - 60));
  canvas.drawParagraph(
    paragraph,
    ui.Offset(textLeft, (height - paragraph.height) / 2),
  );

  final image = await recorder.endRecording().toImage(
    width.round(),
    height.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote feature graphic at 1024x500');
}

Future<void> _write(
  String path,
  double size, {
  bool background = true,
  double contentScale = 1,
}) async {
  final recorder = ui.PictureRecorder();
  paintIcon(
    ui.Canvas(recorder),
    size,
    background: background,
    contentScale: contentScale,
  );
  final image = await recorder.endRecording().toImage(
    size.round(),
    size.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${p.relative(path, from: p.dirname(path))} at ${size.round()}px');
}
