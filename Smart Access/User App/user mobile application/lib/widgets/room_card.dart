// lib/widgets/room_card.dart
import 'package:flutter/material.dart';
import '../models/room.dart';
import '../widgets/glass_card.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  IconData _getRoomIcon(String roomName) {
    final lowercaseName = roomName.toLowerCase();
    
    if (lowercaseName.contains('lab')) return Icons.science;
    if (lowercaseName.contains('office')) return Icons.business;
    if (lowercaseName.contains('server')) return Icons.dns;
    if (lowercaseName.contains('meeting')) return Icons.groups;
    if (lowercaseName.contains('storage')) return Icons.inventory_2;
    if (lowercaseName.contains('entrance')) return Icons.door_front_door;
    
    return Icons.meeting_room;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Room icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getRoomIcon(room.name),
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Room name
            Text(
              room.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Room ID
            Text(
              'ID: ${room.roomId}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            
            // Room group
            if (room.groupName != null)
              Text(
                'Group: ${room.groupName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            
            const Spacer(),
            
            // Status indicator (if room is currently unlocked)
            if (room.isUnlocked) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_open,
                      size: 16,
                      color: Colors.green,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Unlocked',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Access button
            ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(room.isUnlocked ? Icons.login : Icons.lock_open),
              label: Text(room.isUnlocked ? 'Enter' : 'Access'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: room.isUnlocked ? Colors.green : null,
                foregroundColor: room.isUnlocked ? Colors.white : null,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}