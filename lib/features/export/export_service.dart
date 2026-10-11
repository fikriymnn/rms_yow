import 'dart:typed_data';

import 'file_share_web.dart' if (dart.library.io) 'file_share_io.dart' as impl;

/// Android: lembar share. Web: unduh file.
Future<void> shareBytes(String filename, String mime, Uint8List bytes) =>
    impl.shareBytes(filename, mime, bytes);
