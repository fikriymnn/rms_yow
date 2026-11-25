import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import 'voice_service.dart';

const _sample = 'Pesanan untuk meja 4 sudah dibuat';

/// Pilih mesin & suara bahasa Indonesia yang terpasang di HP ini.
class VoicePickerPage extends ConsumerStatefulWidget {
  const VoicePickerPage({super.key});
  @override
  ConsumerState<VoicePickerPage> createState() => _VoicePickerPageState();
}

class _VoicePickerPageState extends ConsumerState<VoicePickerPage> {
  List<String> _engines = const [];
  String? _engine; // null = bawaan HP
  List<VoiceOption>? _voices;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    setState(() => _loading = true);
    final svc = ref.read(voiceServiceProvider);
    final s = ref.read(voiceSettingsProvider).value;
    if (first) {
      _engines = await svc.engines();
      _engine = s?.engine;
    }
    final v = await svc.indonesianVoices(engine: _engine);
    if (!mounted) return;
    setState(() {
      _voices = v;
      _loading = false;
    });
  }

  Future<void> _choose(VoiceOption? v) async {
    final s = ref.read(voiceSettingsProvider).value;
    if (s == null) return;
    await ref
        .read(voiceSettingsProvider.notifier)
        .save(s.withVoice(engine: _engine, name: v?.name, locale: v?.locale));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(v == null ? 'Memakai suara bawaan' : 'Suara dipilih: ${v.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(voiceSettingsProvider).value;
    final svc = ref.read(voiceServiceProvider);
    final voices = _voices ?? const <VoiceOption>[];
    final sameEngine = (s?.engine) == _engine;

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih suara')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Suara berasal dari mesin text-to-speech di HP ini. Suara "online" umumnya lebih natural '
            'tapi butuh internet; bila offline, HP otomatis memakai suara offline.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: AppColors.muted),
          ),
          if (_engines.length > 1) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Mesin suara',
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Bawaan HP'),
                    selected: _engine == null,
                    onSelected: (_) {
                      _engine = null;
                      _load();
                    },
                  ),
                  for (final e in _engines)
                    ChoiceChip(
                      label: Text(engineLabel(e)),
                      selected: _engine == e,
                      onSelected: (_) {
                        _engine = e;
                        _load();
                      },
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SectionCard(
            title: 'Suara bahasa Indonesia',
            child: _loading
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: AppLoader()))
                : Column(
                    children: [
                      _row(
                        title: 'Suara bawaan',
                        sub: 'Mengikuti pengaturan HP',
                        selected: sameEngine && s?.voiceName == null,
                        onPick: () => _choose(null),
                        onPlay: () => svc.preview(_sample, engine: _engine),
                      ),
                      for (final v in voices)
                        _row(
                          title: v.label,
                          sub: v.name,
                          selected: sameEngine && s?.voiceName == v.name,
                          onPick: () => _choose(v),
                          onPlay: () => svc.preview(_sample, engine: _engine, voice: v),
                        ),
                      if (voices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Mesin ini tidak punya suara bahasa Indonesia. Pasang lewat Pengaturan HP → '
                            'Sistem → Bahasa → Output text-to-speech → ikon gerigi → Instal data suara.',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4, color: AppColors.faint),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          if (s != null)
            SectionCard(
              title: 'Nada suara',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: s.pitch.clamp(0.8, 1.2),
                    min: 0.8,
                    max: 1.2,
                    divisions: 4,
                    label: s.pitch < 0.95 ? 'Rendah' : (s.pitch > 1.05 ? 'Tinggi' : 'Normal'),
                    onChanged: (v) => ref.read(voiceSettingsProvider.notifier).save(s.copyWith(pitch: v)),
                  ),
                  Text(
                    'Nada sedikit lebih rendah sering terdengar lebih tenang dan tidak "robot".',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.faint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row({
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onPick,
    required VoidCallback onPlay,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
      color: selected ? AppColors.primary : AppColors.faint,
    ),
    title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
    subtitle: Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.faint)),
    trailing: IconButton(tooltip: 'Dengarkan', icon: const Icon(Icons.play_circle_outline), onPressed: onPlay),
    onTap: onPick,
  );
}
