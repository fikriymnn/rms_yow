import 'package:flutter/material.dart';

/// Tema warna per klien (dipilih owner, sama untuk semua outlet & perangkat klien itu).
///
/// Setiap tema memakai peran warna yang sama:
/// - primary : aksi utama, item navigasi aktif, angka yang perlu ditindak
/// - ink     : struktur gelap (rail/sidebar, kartu ringkasan)
/// - sage    : aksen ketiga = status baik/positif ("Siap", "Tepat waktu")
/// - bg dst. : latar & netral (hangat / sejuk mengikuti tema)
/// Teks utama di setiap tema lolos kontras WCAG AA (>= 4.5:1).
class AppPalette {
  const AppPalette({
    required this.key,
    required this.name,
    required this.description,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.rose,
    required this.roseSoft,
    required this.ink,
    required this.inkSoft,
    required this.inkLine,
    required this.onInkMuted,
    required this.sage,
    required this.sageSoft,
    required this.sageInk,
    required this.sageOnInk,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.sunken,
    required this.muted,
    required this.faint,
    required this.border,
    required this.divider,
  });

  final String key;
  final String name;
  final String description;
  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color rose;
  final Color roseSoft;
  final Color ink;
  final Color inkSoft;
  final Color inkLine;
  final Color onInkMuted;
  final Color sage;
  final Color sageSoft;
  final Color sageInk;
  final Color sageOnInk;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color sunken;
  final Color muted;
  final Color faint;
  final Color border;
  final Color divider;

  static AppPalette get kovalen => all.first;

  static AppPalette byKey(String? key) =>
      all.firstWhere((p) => p.key == key, orElse: () => all.first);

  static const all = <AppPalette>[
  AppPalette(
    key: 'kovalen',
    name: 'Kovalen',
    description: 'Maroon & arang — identitas RMS',
    primary: Color(0xFF7D0B1E),
    primaryDeep: Color(0xFF5C0816),
    primarySoft: Color(0xFFF5E4E7),
    rose: Color(0xFFC2263F),
    roseSoft: Color(0xFFFBE4E8),
    ink: Color(0xFF171717),
    inkSoft: Color(0xFF2A2826),
    inkLine: Color(0xFF3A3734),
    onInkMuted: Color(0xFFA8A29C),
    sage: Color(0xFF6F8467),
    sageSoft: Color(0xFFE7EDE3),
    sageInk: Color(0xFF4A5C44),
    sageOnInk: Color(0xFF93A98A),
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFAF7),
    sunken: Color(0xFFECE6DD),
    muted: Color(0xFF6E6862),
    faint: Color(0xFF8C857E),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
  ),
  AppPalette(
    key: 'terakota',
    name: 'Terakota',
    description: 'Bata hangat ala dapur kayu',
    primary: Color(0xFFB4442A),
    primaryDeep: Color(0xFF873320),
    primarySoft: Color(0xFFF6E9E5),
    rose: Color(0xFFC74336),
    roseSoft: Color(0xFFF8ECEA),
    ink: Color(0xFF24170F),
    inkSoft: Color(0xFF362A22),
    inkLine: Color(0xFF453A33),
    onInkMuted: Color(0xFFACA7A4),
    sage: Color(0xFF5F7A61),
    sageSoft: Color(0xFFE7EBE7),
    sageInk: Color(0xFF5A745C),
    sageOnInk: Color(0xFF879B88),
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFAF7),
    sunken: Color(0xFFECE6DD),
    muted: Color(0xFF6E6862),
    faint: Color(0xFF8C857E),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
  ),
  AppPalette(
    key: 'zaitun',
    name: 'Zaitun',
    description: 'Hijau zaitun segar, cocok resto sehat',
    primary: Color(0xFF2F6B4F),
    primaryDeep: Color(0xFF23503B),
    primarySoft: Color(0xFFE6EDEA),
    rose: Color(0xFF636052),
    roseSoft: Color(0xFFEAF0ED),
    ink: Color(0xFF14211B),
    inkSoft: Color(0xFF27332D),
    inkLine: Color(0xFF37423D),
    onInkMuted: Color(0xFFA6ABA8),
    sage: Color(0xFF3E8C83),
    sageSoft: Color(0xFFE2EEEC),
    sageInk: Color(0xFF357870),
    sageOnInk: Color(0xFF6EA9A2),
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFAF7),
    sunken: Color(0xFFECE6DD),
    muted: Color(0xFF6E6862),
    faint: Color(0xFF8C857E),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
  ),
  AppPalette(
    key: 'kopi',
    name: 'Kopi',
    description: 'Cokelat kopi untuk kafe & bakery',
    primary: Color(0xFF6B4226),
    primaryDeep: Color(0xFF50321C),
    primarySoft: Color(0xFFEDE8E5),
    rose: Color(0xFF904133),
    roseSoft: Color(0xFFF0ECE9),
    ink: Color(0xFF1E1712),
    inkSoft: Color(0xFF302A25),
    inkLine: Color(0xFF403A36),
    onInkMuted: Color(0xFFAAA7A5),
    sage: Color(0xFF4F7C74),
    sageSoft: Color(0xFFE5EBEA),
    sageInk: Color(0xFF4B766E),
    sageOnInk: Color(0xFF7B9D97),
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFAF7),
    sunken: Color(0xFFECE6DD),
    muted: Color(0xFF6E6862),
    faint: Color(0xFF8C857E),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
  ),
  AppPalette(
    key: 'samudra',
    name: 'Samudra',
    description: 'Biru laut untuk seafood & resto modern',
    primary: Color(0xFF1F4E79),
    primaryDeep: Color(0xFF173B5B),
    primarySoft: Color(0xFFE4EAEF),
    rose: Color(0xFF574A71),
    roseSoft: Color(0xFFE9EDF2),
    ink: Color(0xFF0F1A26),
    inkSoft: Color(0xFF222C37),
    inkLine: Color(0xFF333C47),
    onInkMuted: Color(0xFFA4A8AD),
    sage: Color(0xFF3A8F6B),
    sageSoft: Color(0xFFE1EEE9),
    sageInk: Color(0xFF327B5C),
    sageOnInk: Color(0xFF6BAB90),
    bg: Color(0xFFF2F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF9FBFC),
    sunken: Color(0xFFE3E9EE),
    muted: Color(0xFF5F6B75),
    faint: Color(0xFF7E8993),
    border: Color(0xFFDCE3E9),
    divider: Color(0xFFE8EDF1),
  ),
  AppPalette(
    key: 'kunyit',
    name: 'Kunyit',
    description: 'Kuning kunyit, ceria untuk masakan Nusantara',
    primary: Color(0xFFA8560A),
    primaryDeep: Color(0xFF7E4008),
    primarySoft: Color(0xFFF5EBE2),
    rose: Color(0xFFBE501E),
    roseSoft: Color(0xFFF6EEE6),
    ink: Color(0xFF1F1710),
    inkSoft: Color(0xFF312A23),
    inkLine: Color(0xFF413A34),
    onInkMuted: Color(0xFFAAA7A4),
    sage: Color(0xFF2C7A74),
    sageSoft: Color(0xFFDFEBEA),
    sageInk: Color(0xFF2A746E),
    sageOnInk: Color(0xFF619B97),
    bg: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFAF7),
    sunken: Color(0xFFECE6DD),
    muted: Color(0xFF6E6862),
    faint: Color(0xFF8C857E),
    border: Color(0xFFE7E1D8),
    divider: Color(0xFFEFEAE2),
  ),
  AppPalette(
    key: 'anggur',
    name: 'Anggur',
    description: 'Ungu anggur, elegan untuk fine dining',
    primary: Color(0xFF5A2A55),
    primaryDeep: Color(0xFF442040),
    primarySoft: Color(0xFFEBE5EB),
    rose: Color(0xFF832F56),
    roseSoft: Color(0xFFEEEAEE),
    ink: Color(0xFF1A1219),
    inkSoft: Color(0xFF2C252B),
    inkLine: Color(0xFF3C363C),
    onInkMuted: Color(0xFFA8A5A8),
    sage: Color(0xFF6A8F5E),
    sageSoft: Color(0xFFE9EEE7),
    sageInk: Color(0xFF56744D),
    sageOnInk: Color(0xFF8FAB86),
    bg: Color(0xFFF5F4F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAF9F8),
    sunken: Color(0xFFE9E6E3),
    muted: Color(0xFF69655F),
    faint: Color(0xFF89847E),
    border: Color(0xFFE3E0DC),
    divider: Color(0xFFECE9E6),
  ),
  AppPalette(
    key: 'matcha',
    name: 'Matcha',
    description: 'Hijau matcha lembut ala kedai Jepang',
    primary: Color(0xFF4E6B1F),
    primaryDeep: Color(0xFF3B5017),
    primarySoft: Color(0xFFEAEDE4),
    rose: Color(0xFF7A602E),
    roseSoft: Color(0xFFEDF0E9),
    ink: Color(0xFF171C12),
    inkSoft: Color(0xFF2A2E25),
    inkLine: Color(0xFF3A3E36),
    onInkMuted: Color(0xFFA7A9A5),
    sage: Color(0xFF3D7F74),
    sageSoft: Color(0xFFE2ECEA),
    sageInk: Color(0xFF3A796E),
    sageOnInk: Color(0xFF6E9F97),
    bg: Color(0xFFF5F4F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAF9F8),
    sunken: Color(0xFFE9E6E3),
    muted: Color(0xFF69655F),
    faint: Color(0xFF89847E),
    border: Color(0xFFE3E0DC),
    divider: Color(0xFFECE9E6),
  ),
  ];
}
