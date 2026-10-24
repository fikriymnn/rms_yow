import 'package:flutter/material.dart';

/// Royal Violet & Charcoal: ±60% latar, ±30% permukaan, ±10% aksen.
abstract final class AppColors {
  static const primary = Color(
    0xFF7C3AED,
  ); // navigasi aktif, tombol utama, konfirmasi pembayaran
  static const primarySoft = Color(0xFFEDE9FE); // item terpilih, chip
  static const rose = Color(0xFFF43F5E); // aksen kuliner: lencana, sorotan
  static const roseSoft = Color(0xFFFFE4E6);
  static const bg = Color(0xFFF9FAFB); // latar halaman
  static const surface = Color(0xFFFFFFFF); // kartu
  static const ink = Color(0xFF1E1B4B); // teks dan sidebar
  static const inkSoft = Color(0xFF312E81);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}
