class DiningTable {
  const DiningTable({required this.id, required this.name, this.capacity = 4});
  final String id;
  final String name;
  final int capacity;

  DiningTable copyWith({String? name, int? capacity}) => DiningTable(
    id: id,
    name: name ?? this.name,
    capacity: capacity ?? this.capacity,
  );

  factory DiningTable.fromMap(Map<String, dynamic> m) => DiningTable(
    id: m['id'] as String,
    name: m['name'] as String? ?? '',
    capacity: (m['capacity'] as num?)?.toInt() ?? 4,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'capacity': capacity,
  };
}
