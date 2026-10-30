import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rms_yow/features/attendance/location_service.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/ui_kit.dart';

class _AdminOutlet {
  _AdminOutlet.fromJson(Map<String, dynamic> m)
    : id = m['id'] as String,
      name = m['name'] as String? ?? '',
      address = m['address'] as String? ?? '',
      lat = (m['lat'] as num?)?.toDouble(),
      lng = (m['lng'] as num?)?.toDouble(),
      radiusM = (m['radius_m'] as num?)?.toInt() ?? 100,
      active = m['active'] as bool? ?? true;

  final String id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final int radiusM;
  final bool active;
}

class OutletsAdminPage extends ConsumerStatefulWidget {
  const OutletsAdminPage({super.key});
  @override
  ConsumerState<OutletsAdminPage> createState() => _OutletsAdminPageState();
}

class _OutletsAdminPageState extends ConsumerState<OutletsAdminPage> {
  late Future<List<_AdminOutlet>> _future = _load();

  Future<List<_AdminOutlet>> _load() async {
    final data =
        await ref.read(apiClientProvider).get('/outlets') as List<dynamic>;
    return [
      for (final m in data) _AdminOutlet.fromJson(m as Map<String, dynamic>),
    ];
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _edit(_AdminOutlet? o) async {
    final name = TextEditingController(text: o?.name);
    final addr = TextEditingController(text: o?.address);
    final lat = TextEditingController(text: o?.lat?.toString() ?? '');
    final lng = TextEditingController(text: o?.lng?.toString() ?? '');
    final radius = TextEditingController(text: '${o?.radiusM ?? 100}');
    var active = o?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(o == null ? 'Outlet baru' : 'Edit outlet'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nama outlet'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addr,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lokasi untuk absensi',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Pakai lokasi saya'),
                      onPressed: () async {
                        try {
                          await ensureLocationReady();
                          final f = await currentFix();
                          setS(() {
                            lat.text = f.lat.toStringAsFixed(6);
                            lng.text = f.lng.toStringAsFixed(6);
                          });
                          _toast(
                            'Akurasi ±${f.accuracy.round()} m. Lakukan di tengah outlet.',
                          );
                        } catch (e) {
                          _toast('$e');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: lat,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lng,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: radius,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius absensi (meter, 20–2000)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Titik lokasi dipakai untuk batas absensi. Salin koordinat dari '
                            'Google Maps (tekan lama pada peta).',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (o != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktif'),
                      value: active,
                      onChanged: (v) => setS(() => active = v),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) {
      _toast('Nama outlet wajib diisi');
      return;
    }
    final body = {
      'name': name.text.trim(),
      'address': addr.text.trim(),
      'lat': _num(lat.text),
      'lng': _num(lng.text),
      'radius_m': int.tryParse(radius.text.trim()) ?? 100,
      if (o != null) 'active': active,
    };
    try {
      final api = ref.read(apiClientProvider);
      if (o == null) {
        await api.post('/outlets', data: body);
      } else {
        await api.request('PATCH', '/outlets/${o.id}', data: body);
      }
      _reload();
    } catch (e) {
      _toast(errorText(e));
    }
  }

  Widget _card(_AdminOutlet o) {
    final hasLoc = o.lat != null;
    return Material(
      color: o.active ? AppColors.surface : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _edit(o),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: o.active
                      ? AppColors.primarySoft
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: o.active ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            o.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!o.active) ...[
                          const SizedBox(width: 8),
                          const StatusPill('Nonaktif'),
                        ],
                      ],
                    ),
                    if (o.address.isNotEmpty)
                      Text(
                        o.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StatusPill(
                          hasLoc ? 'Lokasi diatur' : 'Lokasi belum diatur',
                          tone: hasLoc ? Tone.success : Tone.warning,
                        ),
                        if (hasLoc)
                          StatusPill('Radius ${o.radiusM} m', tone: Tone.info),
                      ],
                    ),
                    if (hasLoc)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${o.lat!.toStringAsFixed(5)}, ${o.lng?.toStringAsFixed(5) ?? '-'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola outlet')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(null),
      icon: const Icon(Icons.add_business_outlined),
      label: const Text('Outlet'),
    ),
    body: FutureBuilder<List<_AdminOutlet>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorText(snap.error!)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'Belum ada outlet',
          );
        }
        final inactive = list.where((o) => !o.active).length;
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  StatusPill('${list.length} outlet', tone: Tone.info),
                  if (inactive > 0) StatusPill('$inactive nonaktif'),
                ],
              ),
              const SizedBox(height: 12),
              AdaptiveGrid(
                minTileWidth: 380,
                maxColumns: 3,
                children: [for (final o in list) _card(o)],
              ),
            ],
          ),
        );
      },
    ),
  );
}
