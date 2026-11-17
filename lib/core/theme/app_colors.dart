import 'package:flutter/material.dart';

/// Palet Kovalen: maroon + hitam (selaras logo RMS), ±60% latar, ±30% permukaan, ±10% aksen.
abstract final class AppColors {
  static const primary = Color(
    0xFF7D0B1E,
  ); // maroon Kovalen: navigasi aktif, tombol utama, konfirmasi pembayaran
  static const primarySoft = Color(0xFFF7E6E9); // item terpilih, chip
  static const rose = Color(0xFFC2263F); // aksen: lencana, sorotan (keluarga maroon)
  static const roseSoft = Color(0xFFFBE4E8);
  static const bg = Color(0xFFF8F7F5); // latar halaman (putih hangat)
  static const surface = Color(0xFFFFFFFF); // kartu
  static const ink = Color(0xFF171717); // hitam Kovalen: teks dan sidebar
  static const inkSoft = Color(0xFF2C2C2C);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
}
