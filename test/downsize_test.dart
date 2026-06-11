import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:downsize/downsize.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// A noisy image that compresses poorly, so re-encoding always wins.
img.Image noisyImage(int width, int height, {int numChannels = 3}) {
  final image = img.Image(
    width: width,
    height: height,
    numChannels: numChannels,
  );
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        image.width - 1 - x,
        y,
        (x * 7) % 256,
        (y * 13) % 256,
        (x + y) % 256,
        255,
      );
    }
  }
  return image;
}

/// A randomly colored image, where fewer palette colors mean smaller output.
img.Image randomImage(int width, int height, {int numChannels = 3}) {
  final random = Random(42);
  final image = img.Image(
    width: width,
    height: height,
    numChannels: numChannels,
  );
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, random.nextInt(256), random.nextInt(256),
          random.nextInt(256), 255);
    }
  }
  return image;
}

void main() {
  final data =
      File('${Directory.current.path}/example/test.png').readAsBytesSync();

  group('Downsize Image', () {
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

    test('Output is never larger than the input', () async {
      // A tiny, already-optimal PNG that re-encoding could only grow.
      final source = img.Image(width: 8, height: 8);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      final png = img.encodePng(source);
      final compressed = await Downsize.downsize(data: png);
      expect(compressed!.lengthInBytes, lessThanOrEqualTo(png.lengthInBytes));
    });

    test('maxSize is honored on JPG input', () async {
      final jpg = img.encodeJpg(noisyImage(2400, 1600), quality: 100);
      final maxSize = jpg.sizeKb / 4;
      final compressed = await Downsize.downsize(
        data: jpg,
        maxSize: maxSize,
        minQuality: 10,
      );
      expect(compressed!.sizeKb, lessThanOrEqualTo(maxSize));
    });

    test('Unsupported data throws', () {
      final garbage = Uint8List.fromList(List.filled(128, 42));
      expect(Downsize.downsize(data: garbage), throwsException);
    });
  });

  group('Format handling', () {
    test('JPG input stays JPG', () async {
      final jpg = img.encodeJpg(noisyImage(1200, 800), quality: 100);
      final compressed = await Downsize.downsize(data: jpg);
      expect(img.JpegDecoder().isValidFile(compressed!), isTrue);
      expect(compressed.lengthInBytes, lessThan(jpg.lengthInBytes));
    });

    test('PNG input stays PNG', () async {
      final compressed = await Downsize.downsize(data: data);
      expect(img.PngDecoder().isValidFile(compressed!), isTrue);
    });

    test('BMP input is re-encoded as JPG', () async {
      final bmp = img.encodeBmp(noisyImage(1200, 800));
      final compressed = await Downsize.downsize(data: bmp);
      expect(img.JpegDecoder().isValidFile(compressed!), isTrue);
      expect(compressed.lengthInBytes, lessThan(bmp.lengthInBytes));
    });

    test('GIF input is re-encoded as JPG', () async {
      final gif = img.encodeGif(noisyImage(1200, 800));
      final compressed = await Downsize.downsize(data: gif);
      expect(img.JpegDecoder().isValidFile(compressed!), isTrue);
    });

    test('TGA input is re-encoded as JPG', () async {
      final tga = img.encodeTga(noisyImage(1200, 800));
      final compressed = await Downsize.downsize(data: tga);
      expect(img.JpegDecoder().isValidFile(compressed!), isTrue);
      expect(compressed.lengthInBytes, lessThan(tga.lengthInBytes));
    });
  });

  group('PNG compression', () {
    test('Transparency is flattened onto white', () {
      // Noisy on the right, fully transparent on the left.
      final source = noisyImage(600, 600, numChannels: 4);
      for (var y = 0; y < 600; y++) {
        for (var x = 0; x < 300; x++) {
          source.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
      final png = img.encodePng(source);
      final compressed = Downsize().compressPng(
        image: source,
        config: Config(data: png),
      );
      final result = img.decodeImage(compressed)!;
      // The formerly transparent area must be near-white, not black.
      final pixel = result.getPixel(result.width ~/ 8, result.height ~/ 2);
      expect(pixel.r, greaterThan(180));
      expect(pixel.g, greaterThan(180));
      expect(pixel.b, greaterThan(180));
    });

    test('Palette steps down toward maxSize', () {
      final source = randomImage(800, 800);
      final png = img.encodePng(source);
      final unconstrained = Downsize().compressPng(
        image: source,
        config: Config(data: png),
      );
      final constrained = Downsize().compressPng(
        image: source,
        config: Config(data: png, maxSize: unconstrained.sizeKb / 2),
      );
      expect(
        constrained.lengthInBytes,
        lessThan(unconstrained.lengthInBytes),
      );
    });
  });

  group('minQuality', () {
    test('A higher quality floor produces a larger file', () async {
      final jpg = img.encodeJpg(noisyImage(1600, 1200), quality: 100);
      // maxSize is unreachable, so the quality ladder stops at the floor.
      final highFloor =
          await Downsize.downsize(data: jpg, maxSize: 1, minQuality: 90);
      final lowFloor =
          await Downsize.downsize(data: jpg, maxSize: 1, minQuality: 10);
      expect(
        highFloor!.lengthInBytes,
        greaterThan(lowFloor!.lengthInBytes),
      );
    });
  });

  group('dynamicResize', () {
    final downsize = Downsize();

    test('Images at or below 500px are untouched', () {
      final image = img.Image(width: 500, height: 300);
      final resized = downsize.dynamicResize(image);
      expect(resized.width, 500);
      expect(resized.height, 300);
    });

    test('Images above 500px shrink by 10%', () {
      final resized =
          downsize.dynamicResize(img.Image(width: 800, height: 400));
      expect(resized.width, 720);
    });

    test('Images above 1000px shrink by 25%', () {
      final resized =
          downsize.dynamicResize(img.Image(width: 1600, height: 400));
      expect(resized.width, 1200);
    });

    test('Images above 2000px shrink by 50%', () {
      final resized =
          downsize.dynamicResize(img.Image(width: 3000, height: 400));
      expect(resized.width, 1500);
    });

    test('Portrait images resize by height and keep aspect ratio', () {
      final resized =
          downsize.dynamicResize(img.Image(width: 1000, height: 3000));
      expect(resized.height, 1500);
      expect(resized.width, 500);
    });
  });

  group('Extensions', () {
    test('sizeKb is exact, not rounded to whole kilobytes', () {
      expect(Uint8List(1536).sizeKb, 1.5);
      expect(Uint8List(100).sizeKb, closeTo(0.0977, 0.0001));
      expect(Uint8List(100).sizeKb, greaterThan(0));
    });

    test('File.downsize compresses straight from a file', () async {
      final file = File('${Directory.current.path}/example/test.png');
      final compressed = await file.downsize();
      expect(compressed!.lengthInBytes, lessThan(file.lengthSync()));
    });

    test('Uint8List.downsize matches Downsize.downsize', () async {
      final viaExtension = await data.downsize(maxSize: 300);
      final viaClass = await Downsize.downsize(data: data, maxSize: 300);
      expect(viaExtension!.lengthInBytes, viaClass!.lengthInBytes);
    });
  });
}
