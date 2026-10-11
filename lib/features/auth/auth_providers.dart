import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rms_yow/core/db/app_database.dart';
import 'package:rms_yow/core/sync/sync_controller.dart';

enum AppRole { owner, manager, cashier, waiter, kitchen, warehouse }

class AppUser {
  const AppUser({required this.uid, required this.name, required this.role});
  final String uid;
  final String name;
  final AppRole role;

  bool get canManageMenu => role == AppRole.owner || role == AppRole.manager;
  bool get canPay =>
      role == AppRole.owner ||
      role == AppRole.manager ||
      role == AppRole.cashier;
  bool get isManager => role == AppRole.owner || role == AppRole.manager;
}

final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Profil + role dari `users/{uid}`; disimpan lokal agar bisa dibuka offline.
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final db = ref.read(databaseProvider);
  final cacheId = 'profile_${user.uid}';
  Map<String, dynamic>? data;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 4));
    data = doc.data();
    if (data != null) {
      await db.upsert(
        DocsCompanion(
          collection: const Value('device_settings'),
          id: Value(cacheId),
          json: Value(jsonEncode(data)),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          deleted: const Value(false),
          dirty: const Value(false),
        ),
      );
    }
  } catch (_) {
    final row = await db.find('device_settings', cacheId);
    if (row != null) data = jsonDecode(row.json) as Map<String, dynamic>;
  }
  if (data == null) return null;
  return AppUser(
    uid: user.uid,
    name: data['name'] as String? ?? user.email ?? '-',
    role: AppRole.values.firstWhere(
      (r) => r.name == data!['role'],
      orElse: () => AppRole.waiter,
    ),
  );
});
