/// 歌单实体模型
class Playlist {
  final int id;
  final String type; // 'normal' 或 'radio'
  final String name;
  final String? description;
  final String? coverPath;
  final String? coverUrl;
  final List<String> labels; // ["built_in"] 或 ["auto_created"]
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.coverPath,
    this.coverUrl,
    this.labels = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      type: json['type'] as String? ?? 'normal',
      name: json['name'] as String,
      description: json['description'] as String?,
      coverPath: json['cover_path'] as String?,
      coverUrl: json['cover_url'] as String?,
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'description': description,
      'cover_path': coverPath,
      'cover_url': coverUrl,
      'labels': labels,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Playlist copyWith({
    int? id,
    String? type,
    String? name,
    String? description,
    String? coverPath,
    String? coverUrl,
    List<String>? labels,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      coverUrl: coverUrl ?? this.coverUrl,
      labels: labels ?? this.labels,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 是否是内置歌单
  bool get isBuiltIn => labels.contains('built_in');

  /// 是否是自动创建的歌单
  bool get isAutoCreated => labels.contains('auto_created');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Playlist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 歌单列表响应
class PlaylistListResponse {
  final List<Playlist> playlists;
  final int total;

  const PlaylistListResponse({
    required this.playlists,
    required this.total,
  });

  factory PlaylistListResponse.fromJson(Map<String, dynamic> json) {
    final playlistsList = (json['playlists'] as List<dynamic>?)
            ?.map((e) => Playlist.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return PlaylistListResponse(
      playlists: playlistsList,
      total: json['total'] as int? ?? playlistsList.length,
    );
  }
}
