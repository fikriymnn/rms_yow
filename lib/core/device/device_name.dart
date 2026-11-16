import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nama perangkat dari sistem (tidak bisa diubah pengguna), mis. "Samsung SM-T295".
final deviceNameProvider = FutureProvider<String>((ref) => readDeviceName());

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

Future<String> readDeviceName() async {
  final info = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      return 'Browser ${_cap(w.browserName.name)}';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        final maker = _cap(a.manufacturer.trim());
        final model = a.model.trim();
        // model kadang sudah diawali merek (mis. "Pixel 7" vs "Google Pixel 7")
        return model.toLowerCase().startsWith(maker.toLowerCase())
            ? model
            : '$maker $model'.trim();
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return i.name.isNotEmpty ? i.name : i.model;
      case TargetPlatform.windows:
        return (await info.windowsInfo).computerName;
      case TargetPlatform.macOS:
        return (await info.macOsInfo).computerName;
      case TargetPlatform.linux:
        return (await info.linuxInfo).prettyName;
      default:
        return 'Perangkat';
    }
  } catch (_) {
    return 'Perangkat';
  }
}
