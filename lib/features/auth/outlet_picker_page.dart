import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/form_dialog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';
import 'auth_providers.dart';

class OutletPickerPage extends ConsumerStatefulWidget {
  const OutletPickerPage({super.key, this.canPop = false});
  final bool canPop;
  @override
  ConsumerState<OutletPickerPage> createState() => _OutletPickerPageState();
}

class _OutletPickerPageState extends ConsumerState<OutletPickerPage> {
  late Future<List<OutletInfo>> _future = _load();

  Future<List<OutletInfo>> _load() async {
    final data =
        await ref.read(apiClientProvider).get('/outlets') as List<dynamic>;
    return [
      for (final m in data) OutletInfo.fromJson(m as Map<String, dynamic>),
    ];
  }

  void _reload() => setState(() {
    _future = _load();
  });

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Owner bisa membuat outlet langsung dari sini (penting: /docs dimatikan di produksi).
  Future<void> _create() async {
    final r = await formDialog(context, 'Outlet baru', [
      'Nama outlet',
      'Alamat',
    ], okLabel: 'Buat');
    if (r == null) return;
    if (r[0].trim().isEmpty) {
      _toast('Nama outlet wajib diisi');
      return;
    }
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/outlets',
            data: {
              'name': r[0].trim(),
              'address': r[1].trim(),
              'lat': null,
              'lng': null,
              'radius_m': 100,
            },
          );
      _reload();
      _toast('Outlet dibuat. Atur lokasinya di Akun → Kelola outlet.');
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Future<void> _select(OutletInfo o) async {
    await ref.read(ownerOutletProvider.notifier).select(o);
    if (widget.canPop && mounted) Navigator.pop(context);
  }

  Widget _card(OutletInfo o, bool active) {
    final hasLoc = o.lat != null && o.lng != null;
    return Material(
      color: active ? AppColors.primarySoft : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _select(o),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (active)
                          const StatusPill('Aktif', tone: Tone.success),
                        StatusPill(
                          hasLoc ? 'Lokasi diatur' : 'Lokasi belum diatur',
                          tone: hasLoc ? Tone.neutral : Tone.warning,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(activeOutletIdProvider);
    final name = ref.watch(sessionProvider).value?.user.name ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih outlet'),
        actions: [
          if (!widget.canPop)
            IconButton(
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Outlet'),
      ),
      body: FutureBuilder<List<OutletInfo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 40,
                      color: AppColors.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gagal memuat outlet: ${errorText(snap.error!)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Belum ada outlet',
                      message:
                          'Buat outlet pertama untuk mulai memakai aplikasi.',
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Buat outlet'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppColors.ink, AppColors.inkSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Selamat datang' : 'Halo, $name',
                      style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pilih outlet yang ingin Anda kelola. Anda bisa menggantinya kapan saja di menu Akun.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdaptiveGrid(
                minTileWidth: 340,
                maxColumns: 3,
                children: [for (final o in list) _card(o, o.id == activeId)],
              ),
            ],
          );
        },
      ),
    );
  }
}
