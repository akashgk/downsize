import 'dart:isolate';

/// Runs [task] on a separate isolate so heavy image decoding/encoding
/// doesn't block the calling isolate (e.g. the Flutter UI thread).
Future<R> runTask<R>(R Function() task) => Isolate.run(task);
