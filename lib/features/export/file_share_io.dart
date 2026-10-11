import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

Future<void> shareBytes(String filename, String mime, Uint8List bytes) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: mime, name: filename)],
      fileNameOverrides: [filename],
    ),
  );
}
