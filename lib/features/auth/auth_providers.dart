import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppRole { owner, manager, cashier, waiter, kitchen, warehouse }

class AppUser {
  const AppUser({required this.uid, required this.name, required this.role});
  final String uid;
  final String name;
  final AppRole role;

  bool get canManageMenu => role == AppRole.owner || role == AppRole.manager;
}

final authStateProvider = StreamProvider<User?>(
    (ref) => FirebaseAuth.instance.authStateChanges());

/// Profil + role dari `users/{uid}` (di-set oleh Owner / Admin SDK).
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  final data = doc.data();
  if (data == null) return null;
  return AppUser(
    uid: user.uid,
    name: data['name'] as String? ?? user.email ?? '-',
    role: AppRole.values.firstWhere(
      (r) => r.name == data['role'],
      orElse: () => AppRole.waiter,
    ),
  );
});
