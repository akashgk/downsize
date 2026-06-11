## 1.2.0

- Fix: PNG compression no longer scales the image back up to its original
  dimensions after resizing (transparency is now flattened with a composite
  instead of a `copyResize` round-trip).
- Fix: `sizeKb` no longer rounds to whole kilobytes, so size comparisons
  against `maxSize` are accurate (files under 512 bytes previously reported
  0.0 KB).
- Fix: the compressed result is never larger than the input; the original
  bytes are returned instead.
- Perf: the `maxSize` early-exit now happens before decoding, skipping a full
  decode when the file is already small enough.
- Perf: non-PNG/JPG inputs are no longer encoded to JPG and decoded again
  before compression; the already-decoded image is reused.
- Perf: compression runs on a background isolate via `Isolate.run` on native
  platforms (synchronously on the web), keeping the Flutter UI thread free.
- PNG compression now steps the palette down (128/64/32/16 colors) toward
  `maxSize` when the first pass is still too large.
- Minimum Dart SDK is now 3.0.0 (already required transitively by
  `image` >= 4.x).
- Added a CI workflow (format check, analyzer, tests) and expanded the test
  suite from 1 to 23 tests.
- Docs: fixed the README usage example (it didn't compile), documented the
  compression pipeline, and regenerated the example output image.

## 1.0.0

- Initial version.
