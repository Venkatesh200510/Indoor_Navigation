import 'room.dart';

class RouteResult {
  final Room from;
  final Room to;
  final double totalDistance;
  final List<String> directions;
  final List<String> voiceScript;
  final List<Room> path;
  final List<String> nodeIds;

  RouteResult({
    required this.from,
    required this.to,
    required this.totalDistance,
    required this.directions,
    required this.voiceScript,
    required this.path,
    required this.nodeIds,
  });

  factory RouteResult.fromJson(Map<String, dynamic> j) {
    return RouteResult(
      from: Room.fromJson(
        Map<String, dynamic>.from(j['from'] ?? {}),
      ),
      to: Room.fromJson(
        Map<String, dynamic>.from(j['to'] ?? {}),
      ),
      totalDistance: (j['totalDistance'] as num?)?.toDouble() ?? 0,
      directions: List<String>.from(j['directions'] ?? []),
      voiceScript: List<String>.from(j['voiceScript'] ?? []),
      path: (j['path'] as List? ?? [])
          .map(
            (e) => Room.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      nodeIds: List<String>.from(j['nodeIds'] ?? []),
    );
  }
}

// ============================================================
// PATHWAY IMAGE
// ============================================================

class PathwayImage {
  final String nodeId;
  final String name;
  final String caption;
  final String imageUrl;

  PathwayImage({
    required this.nodeId,
    required this.name,
    required this.caption,
    required this.imageUrl,
  });

  factory PathwayImage.fromJson(
    Map<String, dynamic> j,
  ) {
    return PathwayImage(
      nodeId: j['nodeId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      caption: j['caption'] as String? ?? '',
      imageUrl: j['imageUrl'] as String? ?? '',
    );
  }
}
