// lib/models/room.dart
class Room {
  final int? id; // Make nullable
  final String roomId;
  final String name;
  final bool isUnlocked;
  final DateTime? unlockTimestamp;
  final int? group; // Make nullable
  final String? groupName;
  final int? company;
  final String? companyName;

  Room({
    this.id, // No longer required
    required this.roomId,
    required this.name,
    required this.isUnlocked,
    this.unlockTimestamp,
    this.group, // No longer required
    this.groupName,
    this.company,
    this.companyName,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] != null ? json['id'] as int : null,
      roomId: json['room_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Room',
      isUnlocked: json['is_unlocked'] as bool? ?? false,
      unlockTimestamp: json['unlock_timestamp'] != null 
          ? DateTime.parse(json['unlock_timestamp'])
          : null,
      group: json['group'] != null ? json['group'] as int : null,
      groupName: json['group_name'] as String?,
      company: json['company'] != null ? json['company'] as int : null,
      companyName: json['company_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'is_unlocked': isUnlocked,
      'unlock_timestamp': unlockTimestamp?.toIso8601String(),
      'group': group,
      'group_name': groupName,
      'company': company,
      'company_name': companyName,
    };
  }

  Room copyWith({
    int? id,
    String? roomId,
    String? name,
    bool? isUnlocked,
    DateTime? unlockTimestamp,
    int? group,
    String? groupName,
    int? company,
    String? companyName,
  }) {
    return Room(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockTimestamp: unlockTimestamp ?? this.unlockTimestamp,
      group: group ?? this.group,
      groupName: groupName ?? this.groupName,
      company: company ?? this.company,
      companyName: companyName ?? this.companyName,
    );
  }
}