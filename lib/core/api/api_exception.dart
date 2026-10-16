import 'package:dio/dio.dart' show DioException;

String errorText(Object e) =>
    e is DioException ? 'Tidak ada koneksi ke server' : e.toString();

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int? status;
  final String message;
  @override
  String toString() => message;
}

String apiDetail(dynamic data, int? status) {
  if (data is Map && data['detail'] is String) return data['detail'] as String;
  if (data is Map && data['detail'] is List) return 'Data tidak valid';
  return 'Permintaan gagal (${status ?? '-'})';
}
