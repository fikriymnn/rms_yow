import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'payroll_models.dart';
import 'payslip_view.dart';
import 'package:rms_yow/core/ui/motion.dart';
import 'package:rms_yow/shell/app_bar.dart';

/// Slip gaji milik karyawan sendiri (hanya yang sudah diterbitkan).
class MyPayslipsPage extends ConsumerStatefulWidget {
  const MyPayslipsPage({super.key});
  @override
  ConsumerState<MyPayslipsPage> createState() => _MyPayslipsPageState();
}

class _MyPayslipsPageState extends ConsumerState<MyPayslipsPage> {
  late final Future<List<Payslip>> _future = _load();

  Future<List<Payslip>> _load() async {
    final list = await ref.read(apiClientProvider).get('/payroll/me/payslips') as List<dynamic>;
    return [for (final m in list) Payslip.fromJson(Map<String, dynamic>.from(m as Map))];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RmsAppBar(title: const Text('Slip gaji')),
      body: FutureBuilder<List<Payslip>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', message: errorText(snap.error!));
          }
          final list = snap.data;
          if (list == null) return const Center(child: AppLoader());
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Belum ada slip gaji',
              message: 'Slip gaji muncul di sini setelah diterbitkan oleh owner atau manager.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = list[i];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.border),
                ),
                leading: Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                title: Text(periodText(s.periodStart, s.periodEnd), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                subtitle: Text(s.outletName ?? ''),
                trailing: Text(rupiah.format(s.net), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => _SlipPage(slip: s)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SlipPage extends StatelessWidget {
  const _SlipPage({required this.slip});
  final Payslip slip;

  @override
  Widget build(BuildContext context) {
    final period = periodText(slip.periodStart, slip.periodEnd);
    return Scaffold(
      appBar: RmsAppBar(
        title: const Text('Slip gaji'),
        pageActions: [
          PageAction(
            icon: Icons.ios_share,
            label: 'Bagikan PDF',
            shortLabel: 'Bagikan',
            onPressed: () => sharePayslipPdf(slip, period: period, outlet: slip.outletName),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [PayslipView(slip: slip, period: period, outlet: slip.outletName)],
      ),
    );
  }
}
