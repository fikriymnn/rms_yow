import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
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
    body: FutureBuilder<List<OutletInfo>>(
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
                Text('Gagal memuat outlet: ${snap.error}'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() {
                    _future = _load();
                  }),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Belum ada outlet. Buat dulu lewat /docs (POST /outlets).',
              ),
            ),
          );
        }
        return ListView(
          children: [
            for (final o in list)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(o.name),
                onTap: () async {
                  await ref.read(ownerOutletProvider.notifier).select(o);
                  if (widget.canPop && context.mounted) Navigator.pop(context);
                },
              ),
          ],
        );
      },
    ),
  );
}
