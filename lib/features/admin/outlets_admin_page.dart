import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';

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

  void _reload() => setState(() => _future = _load());

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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama outlet'),
                ),
                TextField(
                  controller: addr,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                ),
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
                TextField(
                  controller: radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Radius absensi (meter, 20–2000)',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Titik lokasi dipakai untuk batas absensi. Salin koordinat dari Google Maps (tekan lama pada peta).',
                    style: TextStyle(fontSize: 12),
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
        return ListView(
          children: [
            for (final o in list)
              ListTile(
                leading: Icon(
                  Icons.storefront_outlined,
                  color: o.active ? null : Theme.of(context).disabledColor,
                ),
                title: Text('${o.name}${o.active ? '' : ' (nonaktif)'}'),
                subtitle: Text(
                  o.lat == null
                      ? 'Lokasi belum diatur'
                      : '${o.lat!.toStringAsFixed(5)}, ${o.lng?.toStringAsFixed(5) ?? '-'} • radius ${o.radiusM} m',
                ),
                onTap: () => _edit(o),
              ),
          ],
        );
      },
    ),
  );
}
