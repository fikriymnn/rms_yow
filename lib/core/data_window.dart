import 'package:flutter/material.dart';

/// Koleksi yang hanya disimpan N hari terakhir di device (berdasarkan updatedAt).
const kWindowDays = <String, int>{
  'orders': 90,
  'audit_logs': 90,
  'item_status': 30,
  'shifts': 180,
};

/// Dokumen berstatus 'open' selalu dimuat, meski lebih lama dari jendela.
const kAlwaysLoadOpen = <String>{'orders', 'shifts'};

/// Peringatan jika periode laporan melewati data yang tersimpan di device.
class WindowNotice extends StatelessWidget {
  const WindowNotice({super.key, required this.rangeStart});
  final DateTime rangeStart;

  @override
  Widget build(BuildContext context) {
    final days = kWindowDays['orders'] ?? 90;
    final limit = DateTime.now().subtract(Duration(days: days));
    if (!rangeStart.isBefore(limit)) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Periode ini melewati data yang tersimpan di device '
        '(±$days hari terakhir). Angka penjualan bisa tidak lengkap.',
      ),
    );
  }
}
