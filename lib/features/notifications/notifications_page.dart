import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rms_yow/core/theme/app_colors.dart';
import 'package:rms_yow/core/ui/ui_kit.dart';

import '../../core/api/api_exception.dart';
import 'notification_providers.dart';
import 'notification_router.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _unreadAtOpen = <String>{}; // yang belum dibaca saat halaman dibuka

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<AppNotification>>>(
      notificationsListProvider,
      (_, next) {
        final fresh = [
          for (final n in next.value ?? <AppNotification>[])
            if (!n.read) n.id,
        ];
        if (fresh.isEmpty) return;
        _unreadAtOpen.addAll(fresh); // tetap ditebalkan selama halaman terbuka
        markNotificationsRead(ref, all: true); // dibuka = otomatis dibaca
      },
      fireImmediately: true,
    );
  }

  IconData _icon(String type) => switch (type) {
    'order' => Icons.soup_kitchen_outlined,
    'proposal' => Icons.lightbulb_outline,
    _ => Icons.task_alt,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsListProvider);
    final fmt = DateFormat('d MMM HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
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
                        padding: const EdgeInsets.only(top: 12, bottom: 12),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('Belum ada notifikasi')),
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          for (final n in list)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => openNotificationTarget(
                                    context,
                                    NotificationTap(n.type, n.refId),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _unreadAtOpen.contains(n.id)
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(9),
                                          decoration: BoxDecoration(
                                            color: toneColors(
                                              n.type == 'order'
                                                  ? Tone.warning
                                                  : Tone.info,
                                            ).bg,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            _icon(n.type),
                                            size: 20,
                                            color: toneColors(
                                              n.type == 'order'
                                                  ? Tone.warning
                                                  : Tone.info,
                                            ).fg,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                n.body,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                fmt.format(
                                                  DateTime.fromMillisecondsSinceEpoch(
                                                    n.createdAt,
                                                  ),
                                                ),
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: const Color(
                                                    0xFF9CA3AF,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_unreadAtOpen.contains(n.id))
                                          const Icon(
                                            Icons.circle,
                                            size: 10,
                                            color: AppColors.rose,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
