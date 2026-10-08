import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
// import 'firebase_options.dart'; // hasil `flutterfire configure`

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline ditangani oleh Drift (local-first), bukan cache Firestore.
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);
  runApp(const ProviderScope(child: RmsApp()));
}
