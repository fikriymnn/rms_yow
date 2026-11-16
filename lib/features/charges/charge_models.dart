enum ChargeKind { tax, service }

/// 10 -> "10", 5.5 -> "5,5"
String percentText(num p) {
  final d = p.toDouble();
  if (d == d.roundToDouble()) return '${d.round()}';
  final s = d.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

/// Satu baris biaya pada order: salinan tarif saat order dibuat / dibayar,
/// jadi mengubah master tidak mengubah order yang sudah dibayar.
class ChargeLine {
  const ChargeLine({
    required this.id,
    required this.name,
    required this.kind,
    required this.percent,
    this.onService = false,
    this.fixedAmount,
  });

  final String id;
  final String name;
  final ChargeKind kind;
  final double percent;
  final bool onService; // pajak dihitung atas subtotal + biaya layanan

  /// Order lama: nominal yang tersimpan, tidak dihitung ulang. null = hitung dari persen.
  final int? fixedAmount;

  String get label => '$name ${percentText(percent)}%';

  bool sameRate(ChargeLine o) =>
      id == o.id &&
      name == o.name &&
      kind == o.kind &&
      percent == o.percent &&
      onService == o.onService;

  Map<String, dynamic> toMap(int amount) => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'percent': percent,
    'onService': onService,
    'amount': amount,
    'fixed': fixedAmount != null,
  };

  factory ChargeLine.fromMap(Map<String, dynamic> m) => ChargeLine(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    kind: m['kind'] == 'service' ? ChargeKind.service : ChargeKind.tax,
    percent: (m['percent'] as num?)?.toDouble() ?? 0,
    onService: m['onService'] == true,
    fixedAmount: m['fixed'] == true ? (m['amount'] as num?)?.toInt() : null,
  );
}

/// Data master pajak / biaya layanan.
class Charge {
  const Charge({
    required this.id,
    required this.name,
    required this.kind,
    required this.percent,
    this.onService = false,
    this.active = true,
  });

  final String id;
  final String name;
  final ChargeKind kind;
  final double percent;
  final bool onService;
  final bool active;

  String get kindLabel => kind == ChargeKind.service ? 'Service' : 'Pajak';

  ChargeLine toLine() => ChargeLine(
    id: id,
    name: name,
    kind: kind,
    percent: percent,
    onService: onService,
  );

  factory Charge.fromMap(Map<String, dynamic> m) => Charge(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    kind: m['kind'] == 'service' ? ChargeKind.service : ChargeKind.tax,
    percent: (m['percent'] as num?)?.toDouble() ?? 0,
    onService: m['onService'] == true,
    active: m['active'] != false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'percent': percent,
    'onService': onService,
    'active': active,
  };
}
