import 'printer_settings.dart';

Future<List<({String name, String mac})>> pairedPrinters() async => [];

Future<void> printBytes(PrinterSettings s, List<int> bytes) async =>
    throw UnsupportedError('Cetak langsung tidak didukung di web');
