class Room {
  final String id;
  final String name;
  final int floor;
  final String type;
  final String description;

  const Room({
    required this.id,
    required this.name,
    required this.floor,
    required this.type,
    this.description = '',
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        floor: j['floor'] is int
            ? j['floor'] as int
            : int.tryParse(j['floor'].toString()) ?? 1,
        type: j['type'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'floor': floor,
        'type': type,
        'description': description,
      };
}