import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import '../auth/auth_providers.dart';
import 'voice_service.dart';

/// Pengaturan pengumuman suara untuk perangkat ini.
class VoiceSettingsPage extends ConsumerStatefulWidget {
  const VoiceSettingsPage({super.key});
  @override
  ConsumerState<VoiceSettingsPage> createState() => _VoiceSettingsPageState();
}

class _VoiceSettingsPageState extends ConsumerState<VoiceSettingsPage> {
  bool? _indonesian;

  @override
  void initState() {
    super.initState();
    ref.read(voiceServiceProvider).checkIndonesian().then((v) {
      if (mounted) setState(() => _indonesian = v);
    });
  }

  void _save(VoiceSettings s) => ref.read(voiceSettingsProvider.notifier).save(s);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(voiceSettingsProvider);
    final s = async.value;
    final foodcourt = ref.watch(activeOutletProvider)?.isFoodcourt ?? false;
    final sampleNew = foodcourt ? 'Pesanan untuk nomor 12 sudah dibuat' : 'Pesanan untuk meja 4 sudah dibuat';
    final sampleReady = foodcourt ? 'Pesanan nomor 12 siap diambil' : 'Pesanan meja 4 siap diantar';
    final voice = ref.read(voiceServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi suara')),
      body: s == null
          ? const Center(child: AppLoader())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Pengaturan ini hanya untuk perangkat ini. Saat aplikasi tertutup, perangkat tetap '
                  'berbunyi lewat notifikasi lalu membacakan pesanannya (butuh internet).',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                if (_indonesian == false) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7EBD6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Suara Bahasa Indonesia belum terpasang di perangkat ini, jadi pengucapan bisa '
                      'terdengar aneh. Pasang di Pengaturan HP → Sistem → Bahasa → Output text-to-speech '
                      '→ Mesin Google → Instal data suara → Bahasa Indonesia.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.45, color: const Color(0xFF8A5A12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SectionCard(
                  title: 'Umumkan',
                  child: Column(
                    children: [
                      _switch(
                        'Pesanan baru',
                        '"$sampleNew" — untuk dapur',
                        s.newOrder,
                        (v) => _save(s.copyWith(newOrder: v)),
                        () => voice.say(sampleNew, once: true),
                      ),
                      const Divider(height: 1),
                      _switch(
                        'Pesanan siap',
                        '"$sampleReady" — untuk pelayan / kasir',
                        s.ready,
                        (v) => _save(s.copyWith(ready: v)),
                        () => voice.say(sampleReady, once: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Perangkat khusus dapur / kasir',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Layar tetap menyala', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          'Selama aplikasi terbuka, layar tidak mati sendiri, jadi aplikasi tidak ditutup sistem '
                          'dan suara selalu lengkap. Pasang tablet ke charger.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted),
                        ),
                        value: s.keepAwake,
                        onChanged: (v) => _save(s.copyWith(keepAwake: v)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Agar bunyi saat aplikasi tertutup tidak tertahan, izinkan aplikasi berjalan di latar '
                        'belakang: Pengaturan HP → Aplikasi → RMS → Baterai → Tidak dibatasi.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, height: 1.45, color: AppColors.faint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: 'Suara',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kecepatan bicara', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Slider(
                        value: s.rate.clamp(0.3, 0.7),
                        min: 0.3,
                        max: 0.7,
                        divisions: 4,
                        label: switch (s.rate) {
                          < 0.4 => 'Lambat',
                          > 0.6 => 'Cepat',
                          _ => 'Normal',
                        },
                        onChanged: (v) => _save(s.copyWith(rate: v)),
                      ),
                      Text('Ulangi pengumuman', style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 kali')),
                          ButtonSegment(value: 2, label: Text('2 kali')),
                        ],
                        selected: {s.repeat},
                        onSelectionChanged: (v) => _save(s.copyWith(repeat: v.first)),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => voice.say(sampleReady),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('Tes suara'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _switch(String title, String sub, bool value, ValueChanged<bool> onChanged, VoidCallback onTest) => Row(
    children: [
      Expanded(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          subtitle: Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: AppColors.muted)),
          value: value,
          onChanged: onChanged,
        ),
      ),
      IconButton(tooltip: 'Dengarkan', onPressed: onTest, icon: const Icon(Icons.play_circle_outline)),
    ],
  );
}
