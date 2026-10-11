import 'package:flutter/material.dart';

class PeriodChips extends StatelessWidget {
  const PeriodChips({super.key, required this.range, required this.onChanged});
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  static DateTimeRange today() {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return DateTimeRange(start: d, end: d);
  }

  static DateTimeRange thisMonth() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month),
      end: DateTime(n.year, n.month + 1, 0),
    );
  }

  static DateTimeRange lastMonth() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month - 1),
      end: DateTime(n.year, n.month, 0),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: range,
    );
    if (r != null) onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, DateTimeRange r) => ChoiceChip(
      label: Text(label),
      selected: range == r,
      onSelected: (_) => onChanged(r),
    );
    final preset =
        range == today() || range == thisMonth() || range == lastMonth();
    return Wrap(
      spacing: 8,
      children: [
        chip('Hari ini', today()),
        chip('Bulan ini', thisMonth()),
        chip('Bulan lalu', lastMonth()),
        ChoiceChip(
          label: const Text('Kustom'),
          selected: !preset,
          onSelected: (_) => _pick(context),
        ),
      ],
    );
  }
}
