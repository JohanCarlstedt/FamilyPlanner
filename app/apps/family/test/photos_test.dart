import 'package:family/src/common/photos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('a photo is downscaled and loses its location before it leaves', () {
    final original = img.Image(width: 3000, height: 2000);
    original.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(59, 1);
    original.exif.imageIfd['Model'] = img.IfdValueAscii('iPhone 18 Pro');
    final jpeg = img.encodeJpg(original);
    expect(img.decodeJpg(jpeg)!.exif.gpsIfd.isEmpty, isFalse);

    final prepared = img.decodeJpg(preparePhoto(jpeg))!;
    expect((prepared.width, prepared.height), (1600, 1067));
    expect(prepared.exif.gpsIfd.isEmpty, isTrue);
    expect(prepared.exif.imageIfd['Model'], isNull);
  });

  test('a small photo keeps its size', () {
    final small = img.encodeJpg(img.Image(width: 800, height: 600));
    final prepared = img.decodeJpg(preparePhoto(small))!;
    expect((prepared.width, prepared.height), (800, 600));
  });
}
