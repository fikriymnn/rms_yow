class MenuAvailability {
  const MenuAvailability({required this.id, this.available = true});
  final String id; // = id menu
  final bool available;

  factory MenuAvailability.fromMap(Map<String, dynamic> m) => MenuAvailability(
    id: m['id'] as String,
    available: m['available'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {'id': id, 'available': available};
}
