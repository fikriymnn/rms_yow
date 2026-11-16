// =============================================================================
// ALAMAT SERVER API
// Aktifkan SATU baris kApiUrl, komentari yang lain. Tanpa garis miring di akhir.
// Mengganti alamat = perangkat diminta aktivasi ulang (token server lain tidak berlaku).
// =============================================================================

// Produksi (VPS)
const kApiUrl = 'https://rms-api.fztama.my.id';

// Lokal - emulator Android (10.0.2.2 = localhost komputer ini)
// const kApiUrl = 'http://10.0.2.2:8000';

// Lokal - Flutter web / Windows di komputer yang sama
// const kApiUrl = 'http://localhost:8000';

// Lokal - HP fisik di WiFi yang sama (ganti dengan IP komputer: ipconfig -> IPv4)
// const kApiUrl = 'http://192.168.1.10:8000';

/// Nomor WhatsApp CS untuk perpanjangan, format internasional tanpa + dan tanpa spasi,
/// mis. 6281234567890. Isi defaultValue di bawah (atau --dart-define=CS_WHATSAPP=...).
/// Kosong = tombol WhatsApp hanya menampilkan petunjuk menghubungi CS.
const kCsWhatsapp = String.fromEnvironment(
  'CS_WHATSAPP',
  defaultValue: '6285974930681',
);
const kCsName = String.fromEnvironment(
  'CS_NAME',
  defaultValue: 'CS Kovalen RMS',
);

/// Aplikasi boleh dipakai offline paling lama sekian hari sejak status langganan terakhir dicek.
const kOfflineGraceDays = 7;
