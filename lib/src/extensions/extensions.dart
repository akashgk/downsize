export 'uint8list.dart';
// The IO version is the default so the analyzer (which always resolves the
// default branch) can see the `File.downsize` extension. Web builds get the
// empty stub.
export 'file.dart'
    if (dart.library.js_interop) 'none.dart'
    if (dart.library.html) 'none.dart';
