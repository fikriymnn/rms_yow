/// Data penggajian dari server (/payroll). Nominal profil gaji hanya untuk pengelola.
library;

const kSchemeLabels = {
  'monthly': 'Gaji pokok bulanan',
  'daily': 'Harian (dari absensi)',
  'monthly_daily': 'Gaji pokok + harian',
};

int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class PayProfile {
  const PayProfile({
    this.scheme = 'monthly',
    this.baseSalary = 0,
    this.dailyRate = 0,
    this.fixedAllowance = 0,
    this.lateDeductionEnabled = false,
    this.overtimeBonusEnabled = false,
    this.bpjsEnabled = false,
    this.bpjsAmount = 0,
    this.pph21Enabled = false,
    this.pph21Amount = 0,
  });

  final String scheme;
  final int baseSalary;
  final int dailyRate;
  final int fixedAllowance;
  /// Potongan terlambat memakai aturan bertingkat outlet.
  final bool lateDeductionEnabled;

  /// Bonus lembur = nominal yang diisi saat lembur di absensi disetujui.
  final bool overtimeBonusEnabled;
  final bool bpjsEnabled;
  final int bpjsAmount;
  final bool pph21Enabled;
  final int pph21Amount;

  bool get usesBase => scheme == 'monthly' || scheme == 'monthly_daily';
  bool get usesDaily => scheme == 'daily' || scheme == 'monthly_daily';

  factory PayProfile.fromJson(Map<String, dynamic> m) => PayProfile(
    scheme: m['scheme'] as String? ?? 'monthly',
    baseSalary: _i(m['base_salary']),
    dailyRate: _i(m['daily_rate']),
    fixedAllowance: _i(m['fixed_allowance']),
    lateDeductionEnabled: m['late_deduction_enabled'] as bool? ?? false,
    overtimeBonusEnabled: m['overtime_bonus_enabled'] as bool? ?? false,
    bpjsEnabled: m['bpjs_enabled'] as bool? ?? false,
    bpjsAmount: _i(m['bpjs_amount']),
    pph21Enabled: m['pph21_enabled'] as bool? ?? false,
    pph21Amount: _i(m['pph21_amount']),
  );

  Map<String, dynamic> toJson() => {
    'scheme': scheme,
    'base_salary': baseSalary,
    'daily_rate': dailyRate,
    'fixed_allowance': fixedAllowance,
    'late_deduction_enabled': lateDeductionEnabled,
    'overtime_bonus_enabled': overtimeBonusEnabled,
    'bpjs_enabled': bpjsEnabled,
    'bpjs_amount': bpjsAmount,
    'pph21_enabled': pph21Enabled,
    'pph21_amount': pph21Amount,
  };
}

class PayEmployee {
  PayEmployee.fromJson(Map<String, dynamic> m)
    : userId = m['user_id'] as String,
      name = m['name'] as String? ?? '',
      position = m['position'] as String? ?? '',
      roleLabel = m['role_label'] as String? ?? '',
      outletId = m['outlet_id'] as String?,
      profile = m['profile'] == null
          ? null
          : PayProfile.fromJson(Map<String, dynamic>.from(m['profile'] as Map));

  final String userId;
  final String name;
  final String position;
  final String roleLabel;
  final String? outletId;
  final PayProfile? profile;
}

class PayLine {
  const PayLine({
    required this.kind,
    required this.label,
    required this.amount,
    this.id = '',
    this.qty,
    this.rate,
    this.auto = false,
  });

  final String id;
  final String kind; // earning | deduction
  final String label;
  final double? qty;
  final int? rate;
  final int amount;
  final bool auto;

  bool get isEarning => kind == 'earning';

  factory PayLine.fromJson(Map<String, dynamic> m) => PayLine(
    id: m['id'] as String? ?? '',
    kind: m['kind'] as String? ?? 'earning',
    label: m['label'] as String? ?? '',
    qty: (m['qty'] as num?)?.toDouble(),
    rate: (m['rate'] as num?)?.toInt(),
    amount: _i(m['amount']),
    auto: m['auto'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'amount': amount,
  };
}

class Payslip {
  Payslip.fromJson(Map<String, dynamic> m)
    : id = m['id'] as String,
      runId = m['run_id'] as String? ?? '',
      userName = m['user_name'] as String? ?? '',
      position = m['position'] as String? ?? '',
      scheme = m['scheme'] as String? ?? 'monthly',
      days = _i((m['attendance'] as Map?)?['days']),
      minutes = _i((m['attendance'] as Map?)?['minutes']),
      lateCount = _i((m['attendance'] as Map?)?['late_count']),
      // lembur yang DISETUJUI (slip lama: lembur terhitung dari jadwal)
      overtimeMinutes = _i(
        (m['attendance'] as Map?)?['overtime_approved_minutes'] ??
            (m['attendance'] as Map?)?['overtime_minutes'],
      ),
      lines = [
        for (final l in (m['lines'] as List? ?? const []))
          PayLine.fromJson(Map<String, dynamic>.from(l as Map)),
      ],
      gross = _i(m['gross']),
      deductions = _i(m['deductions']),
      net = _i(m['net']),
      note = m['note'] as String? ?? '',
      periodStart = m['period_start'] as String?,
      periodEnd = m['period_end'] as String?,
      outletName = m['outlet_name'] as String?,
      publishedAt = (m['published_at'] as num?)?.toInt();

  final String id;
  final String runId;
  final String userName;
  final String position;
  final String scheme;
  final int days;
  final int minutes;
  final int lateCount;
  final int overtimeMinutes;
  final List<PayLine> lines;
  final int gross;
  final int deductions;
  final int net;
  final String note;
  final String? periodStart;
  final String? periodEnd;
  final String? outletName;
  final int? publishedAt;
}

class PayRun {
  PayRun.fromJson(Map<String, dynamic> m)
    : id = m['id'] as String,
      outletId = m['outlet_id'] as String? ?? '',
      outletName = m['outlet_name'] as String? ?? '',
      periodStart = m['period_start'] as String? ?? '',
      periodEnd = m['period_end'] as String? ?? '',
      status = m['status'] as String? ?? 'draft',
      count = _i(m['count']),
      totalNet = _i(m['total_net']),
      publishedAt = (m['published_at'] as num?)?.toInt(),
      slips = [
        for (final s in (m['slips'] as List? ?? const []))
          Payslip.fromJson(Map<String, dynamic>.from(s as Map)),
      ];

  final String id;
  final String outletId;
  final String outletName;
  final String periodStart;
  final String periodEnd;
  final String status;
  final int count;
  final int totalNet;
  final int? publishedAt;
  final List<Payslip> slips;

  bool get isDraft => status == 'draft';
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// "2026-11-01" -> "1 Nov 2026"
String fmtIsoDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return iso ?? '';
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

String periodText(String? start, String? end) => '${fmtIsoDate(start)} – ${fmtIsoDate(end)}';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Periode berjalan dari tanggal mulai (1..28): mis. 21 -> 21 bulan lalu s.d. 20 bulan ini.
(DateTime, DateTime) suggestedPeriod(int startDay, DateTime now) {
  if (startDay <= 1) {
    final s = DateTime(now.year, now.month, 1);
    return (s, DateTime(now.year, now.month + 1, 0));
  }
  final s = now.day >= startDay
      ? DateTime(now.year, now.month, startDay)
      : DateTime(now.year, now.month - 1, startDay);
  return (s, DateTime(s.year, s.month + 1, startDay - 1));
}

/// Satu tingkat potongan keterlambatan: terlambat >= [minMinutes] menit dipotong [amount].
class LateTier {
  const LateTier(this.minMinutes, this.amount);
  final int minMinutes;
  final int amount;

  factory LateTier.fromJson(Map<String, dynamic> m) =>
      LateTier(_i(m['min_minutes']), _i(m['amount']));

  Map<String, dynamic> toJson() => {'min_minutes': minMinutes, 'amount': amount};
}
