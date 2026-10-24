import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_providers.dart';

/// Selama layar ini terbuka, notifikasi terkait otomatis dianggap sudah dibaca:
/// saat dibuka, dan juga saat notifikasi baru untuk layar yang sama masuk.
class MarkReadOnOpen extends ConsumerStatefulWidget {
  const MarkReadOnOpen({
    super.key,
    required this.type,
    this.refId,
    required this.child,
  });
  final String type; // order | approval | proposal
  final String? refId; // kosong = semua notifikasi jenis itu
  final Widget child;

  @override
  ConsumerState<MarkReadOnOpen> createState() => _MarkReadOnOpenState();
}

class _MarkReadOnOpenState extends ConsumerState<MarkReadOnOpen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_mark);
  }

  void _mark() {
    if (!mounted) return;
    markNotificationsRead(ref, refType: widget.type, refId: widget.refId);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(unreadNotificationsProvider, (prev, next) {
      if (next > (prev ?? 0)) _mark(); // ada yang baru masuk saat layar terbuka
    });
    return widget.child;
  }
}
