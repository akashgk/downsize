/// Runs [task] on the current isolate.
///
/// Used on platforms without isolate support (e.g. the web).
Future<R> runTask<R>(R Function() task) async => task();
