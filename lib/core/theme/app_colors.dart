import 'package:flutter/material.dart';

/// Palet RMS: maroon + hitam dari logo, ditambah sage sebagai warna penengah.
///
/// - maroon  : aksi utama, item navigasi aktif, angka yang perlu ditindak
/// - hitam   : struktur (rail/sidebar, kartu ringkasan, tombol sekunder kuat)
/// - sage    : status baik/positif, sorotan kecil di atas latar gelap
/// - latar   : putih hangat (krem tipis) agar tidak terasa "template"
abstract final class AppColors {
  // ---- maroon (Kovalen) ----
  static const primary = Color(0xFF7D0B1E);
  static const primaryDeep = Color(0xFF5C0816); // tekan / hover tombol utama
  static const primarySoft = Color(0xFFF5E4E7); // latar item terpilih, chip
  static const rose = Color(0xFFC2263F); // lencana angka (keluarga maroon)
  static const roseSoft = Color(0xFFFBE4E8);

  // ---- hitam (Kovalen) ----
  static const ink = Color(0xFF171717); // teks utama, rail, kartu gelap
  static const inkSoft = Color(0xFF2A2826); // permukaan di atas latar gelap
  static const inkLine = Color(0xFF3A3734); // garis/batang grafik di latar gelap
  static const onInkMuted = Color(0xFFA8A29C); // teks redup di latar gelap

  // ---- sage (warna ketiga) ----
  static const sage = Color(0xFF6F8467);
  static const sageSoft = Color(0xFFE7EDE3);
  static const sageInk = Color(0xFF4A5C44); // teks sage yang lolos kontras di latar terang
  static const sageOnInk = Color(0xFF93A98A); // sage di atas hitam

  // ---- netral hangat ----
  static const bg = Color(0xFFF6F3EE); // latar halaman
  static const surface = Color(0xFFFFFFFF); // kartu
  static const surfaceAlt = Color(0xFFFBFAF7); // footer panel, baris ganjil
  static const sunken = Color(0xFFECE6DD); // wadah segmen / track
  static const muted = Color(0xFF6E6862); // teks sekunder
  static const faint = Color(0xFF8C857E); // teks tersier, label kecil
  static const border = Color(0xFFE7E1D8);
  static const divider = Color(0xFFEFEAE2);

  // ---- status ----
  static const success = sageInk;
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFC0262D);
}
