# Downsize

[![pub package](https://img.shields.io/pub/v/downsize.svg)](https://pub.dev/packages/downsize)
[![CI](https://github.com/YassineDabbous/downsize/actions/workflows/ci.yml/badge.svg)](https://github.com/YassineDabbous/downsize/actions/workflows/ci.yml)

|  | Origin | Compressed |
|--|--|--|
| size | 2.1 MB | 213 KB |
| image |  <a href="https://raw.githubusercontent.com/YassineDabbous/downsize/refs/heads/main/example/test.png"><img src="https://raw.githubusercontent.com/YassineDabbous/downsize/refs/heads/main/example/test.png" align="left" height="100" width="100"></a> | <a href="https://raw.githubusercontent.com/YassineDabbous/downsize/refs/heads/main/example/compressed.png"><img src="https://raw.githubusercontent.com/YassineDabbous/downsize/refs/heads/main/example/compressed.png" align="left" height="100" width="100"></a> |


**Downsize** is a pure Dart package for image compression across multiple formats, such as JPG, PNG, GIF, BMP, TIFF, TGA, PVR, and ICO. It effectively reduces file sizes while maintaining image quality, featuring dynamic resizing and format-specific compression techniques. Because it's pure Dart, the same API works everywhere Flutter runs: Android, iOS, Web, Windows, macOS, and Linux — no native setup required.

This package is built on top of the **[image](https://pub.dev/packages/image)** Dart package, providing additional functionality for compression and resizing with an easy-to-use API.

## Features

- Supports compression for a wide range of image formats: JPG, PNG, GIF, BMP, TIFF, TGA, PVR, ICO, and more.
- Compresses toward a **target file size** (e.g. ~500 KB) instead of guessing at a quality value.
- Dynamically resizes images based on dimensions to prevent unnecessarily large files.
- **Never grows a file**: if compression wouldn't make the image smaller, the original bytes are returned.
- Runs on a **background isolate** on native platforms, so the UI thread stays responsive.
- Customizable compression quality floor (`minQuality`) and target file size (`maxSize`).
- Specific compression techniques for different formats, such as reducing color depth for PNG files.
- Built-in extensions for easy integration with `Uint8List` and `File` objects.

## Getting started

### Prerequisites

- Dart SDK version **3.0.0** or higher: [Install Dart](https://dart.dev/get-dart).

### Installation

1. Add **downsize** to your project’s `pubspec.yaml` file:

```yaml
dependencies:
  downsize:
```

2. Install the dependencies:

```bash
dart pub get
```

## Usage

Here’s a simple example to compress an image using **Downsize**:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:downsize/downsize.dart';

void main() async {
  File imageFile = File('path/to/your/image.jpg'); // Replace with any supported format

  // Using the "downsize" extension on File.
  Uint8List? compressedData = await imageFile.downsize();

  // OR using the "downsize" extension on Uint8List.
  Uint8List imageData = await imageFile.readAsBytes();
  compressedData = await imageData.downsize();

  // OR using the Downsize class directly, targeting a file size:
  compressedData = await Downsize.downsize(
    data: imageData,
    maxSize: 500, // target ~500 KB
    minQuality: 60, // never drop JPG quality below 60
  );

  // Save the compressed image.
  if (compressedData != null) {
    await File('path/to/save/compressed_image.jpg').writeAsBytes(compressedData);
  }
}
```

The same function works with all supported image formats. Simply provide the image data and specify the desired file size or compression quality.

### Options

| Option | Default | Description |
|--|--|--|
| `maxSize` | `null` | Target file size in KB. If the input is already smaller, it's returned untouched — without even decoding it. |
| `minQuality` | `60` | The lowest JPG quality the compressor is allowed to use while chasing `maxSize`. |

## How it works

1. **Early exit** — if the input is already under `maxSize`, the original bytes are returned immediately, with no decoding at all.
2. **Dynamic resize** — large images are scaled down by their longest side: above 2000 px → 50%, above 1000 px → 75%, above 500 px → 90%.
3. **Format-specific compression**:
   - **PNG** stays PNG: transparency is flattened onto white, then the image is quantized to a 256-color palette. If the result is still over `maxSize`, the palette steps down through 128, 64, 32, and 16 colors.
   - **Everything else** (JPG, GIF, BMP, TIFF, TGA, PVR, ICO, ...) is encoded as JPG starting at quality 90, stepping down by 10 until the result fits `maxSize` or hits `minQuality`.
4. **Never-grow guarantee** — if the "compressed" result would be larger than the input, the original bytes are returned instead.

On native platforms the whole pipeline runs on a background isolate (`Isolate.run`), so calling `downsize` from a Flutter app won't jank the UI. On the web, where isolates aren't available, it runs synchronously.

## Additional information

For more information, visit the [repository](https://github.com/YassineDabbous/downsize). You can report issues or contribute by opening a pull request or an issue on GitHub.

### Contributing

Contributions are welcome! Please ensure your code follows best practices and the included lints. To contribute:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request.

Thank you for using **Downsize**!
