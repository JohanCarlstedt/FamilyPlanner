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
  });
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
