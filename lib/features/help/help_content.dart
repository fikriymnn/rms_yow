/// Isi Panduan penggunaan. Teks saja; gambar (screenshot) opsional di assets/guide/<nama>.png.
/// Bila berkas gambar belum ada, gambar dilewati tanpa error.
library;

import 'package:flutter/material.dart';

/// Satu blok isi: paragraf, daftar poin, langkah bernomor, kotak tips, gambar, atau diagram alur persetujuan.
sealed class HelpBlock {
  const HelpBlock();
}

class HText extends HelpBlock {
  const HText(this.text);
  final String text;
}

class HBullets extends HelpBlock {
  const HBullets(this.items);
  final List<String> items;
}

class HSteps extends HelpBlock {
  const HSteps(this.items);
  final List<String> items;
}

class HTip extends HelpBlock {
  const HTip(this.text, {this.warning = false});
  final String text;
  final bool warning;
}

class HImage extends HelpBlock {
  const HImage(this.asset, this.caption);
  final String asset; // mis. 'assets/guide/role_editor.png'
  final String caption;
}

/// Contoh pengaturan: nama role -> izin penting.
class HRoleTable extends HelpBlock {
  const HRoleTable(this.rows);
  final List<(String role, String perms)> rows;
}

class HApprovalFlow extends HelpBlock {
  const HApprovalFlow();
}

class HelpSection {
  const HelpSection(this.title, this.blocks);
  final String title;
  final List<HelpBlock> blocks;
}

class HelpTopic {
  const HelpTopic(this.id, this.icon, this.title, this.summary, this.sections);
  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final List<HelpSection> sections;
}

const helpTopics = <HelpTopic>[
  HelpTopic(
    'roles',
    Icons.admin_panel_settings_outlined,
    'Role & hak akses',
    'Mengatur siapa boleh melakukan apa, termasuk alur persetujuan.',
    [
      HelpSection('Apa itu role?', [
        HText(
          'Role adalah jabatan di aplikasi (Kasir, Waiter, Kitchen, Gudang, Manager, dll.). Setiap karyawan '
          'punya satu role, dan role menentukan menu serta tombol apa saja yang muncul di aplikasinya.',
        ),
        HBullets([
          'Owner selalu punya akses penuh dan tidak bisa diubah.',
          'Ubah hak akses satu role = berlaku untuk semua karyawan dengan role itu, otomatis dalam ±1 menit.',
          'Role bisa dibuat baru, diganti nama, atau dihapus (bila tidak ada karyawan yang memakainya).',
        ]),
        HImage('assets/guide/role_list.png', 'Daftar role di Data Master → Role & hak akses'),
      ]),
      HelpSection('Membuat role baru', [
        HSteps([
          'Buka Data Master → Role & hak akses, ketuk "Role baru".',
          'Di "Mulai dari", pilih template yang paling mirip (mis. Head Chef, Supervisor) atau Custom bila ingin mengisi sendiri.',
          'Ubah nama bila perlu. Aktifkan "Dikelola manager outlet" bila manager boleh membuat akun dengan role ini.',
          'Buka tiap fitur dan centang aksi yang diperlukan. Setiap aksi ada penjelasan singkat di bawahnya.',
          'Ketuk Simpan.',
        ]),
        HTip(
          'Mencentang aksi apa pun otomatis ikut mencentang "Lihat" pada fitur itu, karena tanpa melihat '
          'fitur tidak bisa dipakai. Mengosongkan "Lihat" mengosongkan seluruh aksi fitur tersebut.',
        ),
        HImage('assets/guide/role_editor.png', 'Form role: pilih template, lalu centang aksi per fitur'),
      ]),
      HelpSection('Alur persetujuan: tingkat 1 dan akhir', [
        HText(
          'Beberapa hal tidak langsung berlaku tetapi harus disetujui dulu: Purchase Order (PO), supplier baru, '
          'bahan baru, dan perubahan pajak. Alurnya dua tingkat:',
        ),
        HApprovalFlow(),
        HBullets([
          'Mengajukan: berikan ke staf yang perlu izin atasan, misalnya Gudang dan Kepala Dapur.',
          'Menyetujui tingkat 1: pemeriksa pertama DI OUTLET YANG SAMA, misalnya Manager. Ia memeriksa apakah '
              'pengajuan masuk akal sebelum diteruskan. Nama role ini yang tampil di status "Menunggu …".',
          'Menyetujui akhir: keputusan final, biasanya hanya Owner. Setelah disetujui di sini, PO terkirim / '
              'supplier dan bahan resmi ditambahkan / pajak berubah.',
          'Melewati tingkat 1: penyetuju akhir boleh langsung menyelesaikan pengajuan tanpa menunggu tingkat 1, '
              'berguna saat manager sedang tidak ada.',
        ]),
        HTip(
          'Jika pengaju sendiri memegang "Menyetujui tingkat 1" (mis. Manager membuat PO), pengajuannya langsung '
          'menunggu persetujuan akhir.',
        ),
      ]),
      HelpSection('Contoh pengaturan yang umum', [
        HRoleTable([
          ('Kasir', 'Pesanan: lihat, tambah, ubah, terima pembayaran · Kas: buka & tutup shift · Menu: atur ketersediaan · Absen sendiri'),
          ('Waiter', 'Meja: lihat · Pesanan: lihat, tambah, ubah · Terima notifikasi item siap diantar · Absen sendiri'),
          ('Kitchen', 'Dapur: lihat, ubah status masak, notifikasi pesanan baru · Menu: atur ketersediaan · Absen sendiri'),
          ('Gudang', 'Bahan & stok: lihat, catat mutasi · PO: buat · Penerimaan barang · Persetujuan: lihat, mengajukan'),
          ('Manager', 'Hampir semua operasional outlet · Laporan & keuangan · Persetujuan: menyetujui tingkat 1 · Kelola pengguna staf'),
          ('Absen bersama', 'Hanya "Menjalankan absensi bersama (kiosk)". Dipakai di tablet absen bersama.'),
        ]),
        HTip(
          'Uang & data sensitif (refund, batalkan item yang sudah dimasak, keuangan, gaji) sebaiknya hanya untuk atasan.',
          warning: true,
        ),
      ]),
      HelpSection('Fitur yang tidak muncul', [
        HText(
          'Fitur dari modul yang tidak termasuk paket langganan Anda (mis. Layar dapur, Reservasi) tidak tampil di '
          'daftar hak akses. Bila modul diaktifkan kemudian, hak akses yang pernah diatur kembali seperti semula.',
        ),
      ]),
    ],
  ),
  HelpTopic(
    'pos',
    Icons.point_of_sale_rounded,
    'Kasir & meja',
    'Mencatat pesanan, pembayaran, diskon, dan struk.',
    [
      HelpSection('Pesanan makan di tempat', [
        HSteps([
          'Buka tab Meja, ketuk meja yang kosong (putih).',
          'Pilih menu, atur jumlah dan catatan (mis. "pedas sedang").',
          'Ketuk "Kirim ke dapur". Meja berubah hitam (terisi).',
          'Saat tamu selesai, buka meja lalu ketuk Bayar, pilih metode, dan cetak struk bila perlu.',
        ]),
        HBullets([
          'Meja hitam = terisi, sage = sudah bayar tapi tamu masih duduk, maroon muda = ada booking.',
          'Titik merah berdenyut = meja sudah terisi lebih dari 45 menit.',
        ]),
        HImage('assets/guide/tables.png', 'Denah meja per status'),
      ]),
      HelpSection('Bawa pulang & foodcourt', [
        HText('Ketuk "Bawa pulang" di halaman Meja. Outlet foodcourt langsung masuk ke kasir tanpa denah meja.'),
      ]),
      HelpSection('Diskon, void, dan refund', [
        HBullets([
          'Diskon butuh izin "Beri diskon".',
          'Membatalkan item yang belum dimasak cukup izin "Hapus"; yang sudah dimasak butuh "Batalkan item yang sudah diproses dapur".',
          'Refund (kembalikan uang) hanya untuk role yang diberi izin Refund. Semua tercatat di log audit.',
        ]),
      ]),
    ],
  ),
  HelpTopic(
    'kitchen',
    Icons.soup_kitchen_outlined,
    'Dapur (KDS)',
    'Layar pesanan untuk dapur dan bar.',
    [
      HelpSection('Cara pakai', [
        HSteps([
          'Pesanan baru muncul otomatis dan berbunyi bila notifikasi diaktifkan.',
          'Ketuk item untuk mengubah status: baru → dimasak → siap.',
          'Pelayan menerima notifikasi "siap diantar" lalu menandai diantar.',
        ]),
        HTip('Pastikan notifikasi HP/tablet dapur diizinkan agar pesanan baru tidak terlewat.'),
      ]),
    ],
  ),
  HelpTopic(
    'shift',
    Icons.account_balance_wallet_outlined,
    'Kas & shift',
    'Modal awal, kas masuk/keluar, dan tutup shift.',
    [
      HelpSection('Alur shift kasir', [
        HSteps([
          'Awal kerja: buka shift dan isi modal awal di laci.',
          'Selama shift: catat kas keluar (mis. beli es batu) atau kas masuk.',
          'Akhir kerja: hitung uang di laci, tutup shift. Aplikasi menunjukkan selisih bila ada.',
        ]),
        HText('Role dengan "Kelola shift milik orang lain" bisa menutup shift kasir lain, mis. bila kasir lupa.'),
      ]),
    ],
  ),
  HelpTopic(
    'stock',
    Icons.inventory_2_outlined,
    'Stok & pembelian',
    'Bahan, resep, PO ke supplier, dan penerimaan barang.',
    [
      HelpSection('Alur pembelian', [
        HSteps([
          'Gudang membuat PO (draf) berisi bahan dan jumlah.',
          'Ajukan PO. PO menunggu persetujuan tingkat 1 lalu akhir (lihat topik Role & hak akses).',
          'Setelah disetujui, PO dikirim ke supplier.',
          'Saat barang datang, catat Penerimaan barang: stok bertambah otomatis.',
          'Catat pembayaran ke supplier untuk melunasi utang.',
        ]),
      ]),
      HelpSection('Resep & stok otomatis', [
        HText(
          'Bila menu punya resep, setiap pesanan yang dibayar memotong stok bahan sesuai takaran dan '
          'menghitung HPP. Menu bertanda "Tanpa resep" tidak memotong stok.',
        ),
        HText('Stok di bawah batas minimum tampil di Beranda pada kartu "Perlu tindakan".'),
      ]),
    ],
  ),
  HelpTopic(
    'approvals',
    Icons.task_alt_rounded,
    'Persetujuan',
    'Meninjau pengajuan PO, supplier, bahan, dan pajak.',
    [
      HelpSection('Meninjau pengajuan', [
        HApprovalFlow(),
        HSteps([
          'Buka menu Persetujuan. Tab pertama berisi pengajuan yang menunggu Anda.',
          'Ketuk pengajuan untuk melihat rinciannya.',
          'Setujui atau tolak dengan catatan. Pengaju menerima notifikasi.',
        ]),
        HText('Pengaju bisa menarik pengajuannya selama belum diputuskan.'),
      ]),
    ],
  ),
  HelpTopic(
    'attendance',
    Icons.fingerprint,
    'Absensi & lembur',
    'Absen dengan foto & lokasi, tablet bersama, koreksi, dan lembur.',
    [
      HelpSection('Absen sendiri', [
        HText('Buka Absensi, ketuk Masuk / Pulang. Aplikasi mengambil foto wajah dan lokasi; harus berada dalam radius outlet.'),
      ]),
      HelpSection('Tablet absen bersama', [
        HSteps([
          'Buat akun karyawan dengan role Absen bersama untuk outlet itu, lalu login di tablet.',
          'Atur PIN tiap karyawan: Data Master → Pengguna → ketuk karyawan → PIN absensi (atau karyawan mengaturnya sendiri di Akun → PIN absensi).',
          'Karyawan memilih namanya di tablet, memasukkan PIN, lalu berfoto.',
        ]),
      ]),
      HelpSection('Tinjauan, koreksi, dan lembur', [
        HBullets([
          'Tandai absensi OK atau mencurigakan berdasarkan foto dan jarak.',
          'Koreksi jam bila karyawan lupa absen pulang; riwayat koreksi tersimpan.',
          'Lembur dihitung dari jadwal pulang outlet. Setujui lembur dan isi nominal bonusnya; bonus masuk slip gaji.',
        ]),
      ]),
    ],
  ),
  HelpTopic(
    'payroll',
    Icons.payments_outlined,
    'Penggajian',
    'Gaji pokok/harian, potongan terlambat, bonus lembur, slip gaji.',
    [
      HelpSection('Menyiapkan gaji', [
        HSteps([
          'Data Master → Penggajian → tab Gaji karyawan: pilih skema (pokok, harian, atau pokok + harian) dan nominalnya.',
          'Aktifkan "Potongan keterlambatan" dan/atau "Bonus lembur" bila dipakai.',
          'Atur tingkat potongan terlambat lewat ikon timer (mis. ≥5 menit Rp10.000, ≥30 menit Rp25.000).',
        ]),
      ]),
      HelpSection('Menerbitkan slip', [
        HSteps([
          'Buat Periode baru. Slip dihitung otomatis dari absensi.',
          'Tambah komponen manual (service charge, bonus, kasbon) bila perlu.',
          'Terbitkan. Karyawan melihat slipnya di Akun → Slip gaji. Slip yang terbit terkunci.',
        ]),
        HTip('Nominal gaji hanya terlihat oleh pemegang izin penggajian. Karyawan tidak pernah melihat pengaturan gajinya.'),
      ]),
    ],
  ),
  HelpTopic(
    'reports',
    Icons.bar_chart_rounded,
    'Laporan & keuangan',
    'Penjualan, menu terlaris, laba rugi, dan ekspor.',
    [
      HelpSection('Isi laporan', [
        HBullets([
          'Laporan: penjualan per hari / periode, menu terlaris, metode bayar, dan ekspor CSV.',
          'Keuangan: biaya operasional dan laba rugi.',
          'Beranda: ringkasan cepat hari ini untuk owner & manager.',
        ]),
      ]),
    ],
  ),
  HelpTopic(
    'account',
    Icons.storefront_outlined,
    'Akun restoran & perangkat',
    'Login dua tahap, perangkat aktif, langganan, dan password.',
    [
      HelpSection('Dua jenis akun', [
        HBullets([
          'Akun restoran (email + password dari Kovalen): dipakai sekali per perangkat untuk mengaktifkan aplikasi.',
          'Akun karyawan (username + password): dipakai tiap orang untuk login setelah perangkat aktif.',
        ]),
        HText(
          'Owner dapat mengganti password akun restoran di Akun → Password akun restoran. '
          'Perangkat yang sudah aktif tidak ikut keluar.',
        ),
      ]),
      HelpSection('Langganan & update', [
        HText('Masa aktif tampil di Akun → Langganan. Untuk perpanjang, hubungi CS lalu masukkan kode kupon.'),
        HText('Bila ada versi baru, aplikasi menampilkan popup pembaruan saat dibuka.'),
      ]),
    ],
  ),
];
