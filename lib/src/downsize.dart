import 'dart:typed_data';

import 'package:downsize/downsize.dart';
import 'package:image/image.dart';

import 'runner/runner_none.dart' if (dart.library.io) 'runner/runner_io.dart';

/// Config class holds raw data with compression options.
class Config {
  /// initial image data.
  final Uint8List data;

  /// minimum image quality.
  final int minQuality;

  /// desired file size.
  final double? maxSize;

  Config({required this.data, this.minQuality = 60, this.maxSize});
}

class Downsize {
  static Future<Uint8List?> downsize({
    required Uint8List data,
    int minQuality = 60,
    double? maxSize,
  }) {
    if (data.isEmpty || (maxSize != null && data.sizeKb <= maxSize)) {
      return Future.value(data);
    }
    final config = Config(
      data: data,
      minQuality: minQuality,
      maxSize: maxSize,
    );
    return runTask(() => Downsize().compress(config));
  }

  /// Decode and Compress image data.
  Uint8List? compress(Config config) {
    // Skip the expensive decode entirely when the file is already small
    // enough.
    if (config.maxSize != null && config.data.sizeKb <= config.maxSize!) {
      return config.data;
    }

    Image? image = decodeImage(config.data);
    if (image == null) {
      throw Exception("Unsupported image type.");
    }

    bool isPng = PngDecoder().isValidFile(config.data);

    // PNG keeps its format; everything else (JPG, GIF, BMP, TIFF, ...) is
    // encoded as JPG.
    final result = isPng
        ? compressPng(image: image, config: config)
        : compressJpg(image: image, config: config);

    // Never return more bytes than we started with.
    if (result.lengthInBytes >= config.data.lengthInBytes) {
      return config.data;
    }
    return result;
  }

  /// Compress JPG image.
  Uint8List compressJpg({
    required Image image,
    required Config config,
    int quality = 90,
    bool preTreatment = true,
  }) {
    if (preTreatment) {
      image = dynamicResize(image);
    }

    var im = encodeJpg(image, quality: quality);
    if (config.maxSize == null) return im;

    while (im.sizeKb > config.maxSize! && quality - 10 >= config.minQuality) {
      quality -= 10;
      im = encodeJpg(image, quality: quality);
    }

    return im;
  }

  /// Compress PNG image.
  Uint8List compressPng({
    required Image image,
    required Config config,
    int level = 9,
  }) {
    image = dynamicResize(image);

    // remove transparency: flatten onto a white background before quantizing.
    if (image.hasAlpha) {
      final background = Image(
        width: image.width,
        height: image.height,
        numChannels: 3,
      );
      background.clear(ColorRgb8(255, 255, 255));
      image = compositeImage(background, image);
    }

    // downsize the number of colors (to 8-bit)
    var im = encodePng(
      quantize(image, numberOfColors: 256),
      level: level,
      filter: PngFilter.none,
    );

    // Step the palette down until the target size is reached.
    if (config.maxSize != null) {
      for (final colors in const [128, 64, 32, 16]) {
        if (im.sizeKb <= config.maxSize!) break;
        final candidate = encodePng(
          quantize(image, numberOfColors: colors),
          level: level,
          filter: PngFilter.none,
        );
        if (candidate.lengthInBytes >= im.lengthInBytes) break;
        im = candidate;
      }
    }

    return im;
  }

  /// Dynamically resize the image based on its dimensions.
  Image dynamicResize(Image image) {
    bool byWidth = image.width > image.height;
    int originalSize = byWidth ? image.width : image.height;
    int size = originalSize;

    if (originalSize > 2000) {
      size = (originalSize * 0.5).round();
    } else if (originalSize > 1000) {
      size = (originalSize * 0.75).round();
    } else if (originalSize > 500) {
      size = (originalSize * 0.9).round();
    } else {
      return image;
    }

    return copyResize(
      image,
      width: byWidth ? size : null,
      height: byWidth ? null : size,
    );
  }
}
