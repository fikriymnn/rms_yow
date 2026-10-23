import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api/api_exception.dart';
import 'notification_providers.dart';
import 'notification_router.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _icon(String type) => switch (type) {
    'order' => Icons.soup_kitchen_outlined,
    'proposal' => Icons.lightbulb_outline,
    _ => Icons.task_alt,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final fmt = DateFormat('d MMM HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all),
            onPressed: () => markNotificationsRead(ref, all: true),
          ),
        ],
      ),
      body: Column(
        children: [
          const _PermissionBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsListProvider);
                await ref.read(notificationsListProvider.future);
              },
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(errorText(e)),
                    ),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('Belum ada notifikasi')),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          for (final n in list)
                            ListTile(
                              isThreeLine: true,
                              leading: Icon(_icon(n.type)),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: n.read
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${n.body}\n${fmt.format(DateTime.fromMillisecondsSinceEpoch(n.createdAt))}',
                              ),
                              trailing: n.read
                                  ? null
                                  : Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              onTap: () async {
                                await markNotificationsRead(ref, ids: [n.id]);
                                if (context.mounted) {
                                  openNotificationTarget(
                                    context,
                                    NotificationTap(n.type, n.refId),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) => FutureBuilder<PermissionStatus>(
    future: Permission.notification.status,
    builder: (context, snap) {
      final s = snap.data;
      if (s == null || s.isGranted) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.notifications_off_outlined),
          title: const Text('Notifikasi dimatikan'),
          subtitle: const Text(
            'Aktifkan agar pesanan dan persetujuan tidak terlewat.',
          ),
          trailing: TextButton(
            onPressed: openAppSettings,
            child: const Text('Buka'),
          ),
        ),
      );
    },
  );
}
