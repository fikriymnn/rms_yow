import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/ui_kit.dart';
import 'client_models.dart';
import 'client_providers.dart';

/// Owner memilih tema warna aplikasi. Berlaku untuk seluruh klien: semua outlet & perangkat.
class ThemePage extends ConsumerStatefulWidget {
  const ThemePage({super.key});
  @override
  ConsumerState<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends ConsumerState<ThemePage> {
  String? _picked;
  bool _saving = false;

  Future<void> _apply(String key) async {
    setState(() => _saving = true);
    try {
      final res = await ref.read(apiClientProvider).post('/client/theme', data: {'theme': key});
      await ref
          .read(clientProvider.notifier)
          .applyInfo(ClientInfo.fromJson(Map<String, dynamic>.from(res as Map)));
      if (!mounted) return;
      setState(() => _picked = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tema diterapkan. Perangkat lain ikut berubah dalam ±1 menit.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(clientProvider).value?.info.theme ?? AppPalette.kovalen.key;
    final selected = _picked ?? current;
    return Scaffold(
      appBar: AppBar(title: const Text('Tema warna')),
      bottomNavigationBar: _picked == null || _picked == current
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _apply(_picked!),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: AppLoader(size: 16, onDark: true))
                      : const Icon(Icons.check_rounded),
                  label: Text('Terapkan tema ${AppPalette.byKey(_picked).name}'),
                ),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Tema berlaku untuk seluruh restoran: semua outlet dan semua perangkat. '
                'Pilih tema lalu ketuk Terapkan.',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 196 * textScaleOf(context),
                ),
                itemCount: AppPalette.all.length,
                itemBuilder: (_, i) {
                  final p = AppPalette.all[i];
                  return Entrance(
                    index: i,
                    child: _ThemeCard(
                      palette: p,
                      selected: p.key == selected,
                      active: p.key == current,
                      onTap: () => setState(() => _picked = p.key),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Pratinjau mini memakai warna tema itu sendiri (bukan tema aktif).
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.palette, required this.selected, required this.active, required this.onTap});
  final AppPalette palette;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    TextStyle t(double size, FontWeight w, Color c) => GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border, width: selected ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // rail gelap + item aktif
            Container(
              width: 46,
              color: p.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 20,
                    decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 10),
                  for (var k = 0; k < 3; k++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      width: 16,
                      height: 4,
                      decoration: BoxDecoration(color: p.onInkMuted, borderRadius: BorderRadius.circular(2)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(p.name, style: t(16, FontWeight.w800, p.ink))),
                        if (active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: p.sageSoft, borderRadius: BorderRadius.circular(999)),
                            child: Text('Dipakai', style: t(11, FontWeight.w700, p.sageInk)),
                          ),
                      ],
                    ),
                    Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: t(11.5, FontWeight.w500, p.muted)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Penjualan', style: t(10.5, FontWeight.w500, p.muted)),
                                Text('Rp 2.450.000', style: t(13, FontWeight.w800, p.ink)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: p.sageSoft, borderRadius: BorderRadius.circular(999)),
                            child: Text('Siap', style: t(11, FontWeight.w700, p.sageInk)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text('Bayar', style: t(12.5, FontWeight.w800, Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
