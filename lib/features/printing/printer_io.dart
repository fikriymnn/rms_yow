import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_settings.dart';

String? _connectedMac;

Future<bool> _ensureBtPermission() async {
  if (await PrintBluetoothThermal.isPermissionBluetoothGranted) return true;
  await Permission.bluetoothConnect.request();
  return PrintBluetoothThermal.isPermissionBluetoothGranted;
}

Future<List<({String name, String mac})>> pairedPrinters() async {
  if (!await _ensureBtPermission()) throw Exception('Izin Bluetooth ditolak');
  final list = await PrintBluetoothThermal.pairedBluetooths;
  return [for (final b in list) (name: b.name, mac: b.macAdress)];
}

Future<void> printBytes(PrinterSettings s, List<int> bytes) async {
  switch (s.type) {
    case PrinterType.none:
      throw Exception('Printer belum diatur (Kas → ikon printer)');
    case PrinterType.lan:
      {
        if (s.lanHost.isEmpty) throw Exception('IP printer belum diisi');
        final sock = await Socket.connect(
          s.lanHost,
          s.lanPort,
          timeout: const Duration(seconds: 5),
        );
        try {
          sock.add(bytes);
          await sock.flush();
        } finally {
          await sock.close();
          sock.destroy();
        }
      }
    case PrinterType.bluetooth:
      await _printBt(s, bytes);
  }
}

Future<void> _printBt(PrinterSettings s, List<int> bytes) async {
  if (s.btAddress.isEmpty) throw Exception('Pilih printer Bluetooth dulu');
  if (!await _ensureBtPermission()) throw Exception('Izin Bluetooth ditolak');
  if (!await PrintBluetoothThermal.bluetoothEnabled) {
    throw Exception('Bluetooth belum aktif');
  }
  final connected = await PrintBluetoothThermal.connectionStatus;
  if (!connected || _connectedMac != s.btAddress) {
    if (connected) await PrintBluetoothThermal.disconnect;
    final conn = await PrintBluetoothThermal.connect(
      macPrinterAddress: s.btAddress,
    );
    if (!conn) throw Exception('Gagal terhubung ke ${s.btName}');
    _connectedMac = s.btAddress;
  }
  final sent = await PrintBluetoothThermal.writeBytes(bytes);
  if (!sent) {
    _connectedMac = null;
    throw Exception('Gagal mengirim data ke printer');
  }
}
