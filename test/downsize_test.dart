import 'dart:io';
import 'dart:typed_data';

import 'package:downsize/downsize.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  group('Downsize Image', () {
    Uint8List data =
        File('${Directory.current.path}/example/test.png').readAsBytesSync();

    test('Reducing size Test', () async {
      double? newSize = (await Downsize.downsize(data: data))?.sizeKb;
      expect(data.sizeKb, greaterThanOrEqualTo(newSize!));
    });

    test('PNG output keeps the reduced dimensions', () async {
      final original = img.decodeImage(data)!;
      final compressed = await Downsize.downsize(data: data);
      final result = img.decodeImage(compressed!)!;
      final originalLongest =
          original.width > original.height ? original.width : original.height;
      final resultLongest =
          result.width > result.height ? result.width : result.height;
      expect(resultLongest, lessThan(originalLongest));
    });

    test('File already under maxSize is returned untouched', () async {
      final compressed =
          await Downsize.downsize(data: data, maxSize: data.sizeKb + 1);
      expect(compressed, same(data));
    });

    test('Empty data is returned as-is', () async {
      final empty = Uint8List(0);
      expect(await Downsize.downsize(data: empty), same(empty));
    });

    test('BMP input is compressed', () async {
      final source = img.Image(width: 1200, height: 800);
      img.fill(source, color: img.ColorRgb8(120, 180, 60));
      final bmp = img.encodeBmp(source);
      final compressed = await Downsize.downsize(data: bmp);
      expect(compressed!.lengthInBytes, lessThan(bmp.lengthInBytes));
      expect(img.JpegDecoder().isValidFile(compressed), isTrue);
    });

    test('Output is never larger than the input', () async {
      // A tiny, already-optimal PNG that re-encoding could only grow.
      final source = img.Image(width: 8, height: 8);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      final png = img.encodePng(source);
      final compressed = await Downsize.downsize(data: png);
      expect(compressed!.lengthInBytes, lessThanOrEqualTo(png.lengthInBytes));
    });

    test('maxSize is honored on JPG input', () async {
      final source = img.Image(width: 2400, height: 1600);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(
              x, y, (x * 7) % 256, (y * 13) % 256, (x + y) % 256);
        }
      }
      final jpg = img.encodeJpg(source, quality: 100);
      final maxSize = jpg.sizeKb / 4;
      final compressed = await Downsize.downsize(
        data: jpg,
        maxSize: maxSize,
        minQuality: 10,
      );
      expect(compressed!.sizeKb, lessThanOrEqualTo(maxSize));
    });
  });
}
