class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.build,
    required this.notes,
    required this.sizeBytes,
    required this.sha256,
    required this.minBuild,
    required this.url,
  });

  final String version;
  final int build; // = versionCode
  final String notes;
  final int sizeBytes;
  final String sha256;
  final int minBuild; // build di bawah ini wajib memperbarui
  final String url; // alamat unduhan lengkap

  bool isNewerThan(int current) => build > current;
  bool isMandatoryFor(int current) => current < minBuild;
  String get sizeText => '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';

  factory UpdateInfo.fromJson(Map<String, dynamic> m, String baseUrl) =>
      UpdateInfo(
        version: m['version'] as String? ?? '',
        build: (m['build'] as num?)?.toInt() ?? 0,
        notes: m['notes'] as String? ?? '',
        sizeBytes: (m['size_bytes'] as num?)?.toInt() ?? 0,
        sha256: m['sha256'] as String? ?? '',
        minBuild: (m['min_build'] as num?)?.toInt() ?? 0,
        url: '$baseUrl${m['download_path'] as String? ?? ''}',
      );
}
