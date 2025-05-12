# core/views/room.py
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from ..models import Room, UserRoomGroup
from ..serializers import RoomSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_user_rooms(request):
    """
    Get all rooms that the current user has access to via their room groups
    """
    user = request.user
    
    # Get user's room groups
    user_room_groups = UserRoomGroup.objects.filter(user=user)
    group_ids = [urg.room_group.id for urg in user_room_groups]
    
    # Get rooms from these groups, filtered by user's company
    rooms = Room.objects.filter(
        company=user.company,
        group__in=group_ids
    ).distinct()
    
    serializer = RoomSerializer(rooms, many=True)
    return Response(serializer.data)
