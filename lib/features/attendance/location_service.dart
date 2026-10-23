import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix(this.lat, this.lng, this.accuracy, this.mocked);
  final double lat;
  final double lng;
  final double accuracy;
  final bool mocked;
}

class LocationException implements Exception {
  LocationException(this.message, {this.openSettings = false});
  final String message;
  final bool openSettings;
  @override
  String toString() => message;
}

Future<void> ensureLocationReady() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw LocationException('GPS/lokasi di HP belum aktif. Aktifkan dulu.');
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied) {
    throw LocationException('Izin lokasi ditolak. Izinkan agar bisa absen.');
  }
  if (p == LocationPermission.deniedForever) {
    throw LocationException(
      'Izin lokasi diblokir. Buka pengaturan aplikasi untuk mengizinkan.',
      openSettings: true,
    );
  }
}

LocationFix _fix(Position p) =>
    LocationFix(p.latitude, p.longitude, p.accuracy, p.isMocked);

Stream<LocationFix> watchLocation() => Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 3,
  ),
).map(_fix);

Future<LocationFix> currentFix() async => _fix(
  await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      timeLimit: Duration(seconds: 20),
    ),
  ),
);
