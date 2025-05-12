# core/views/admin.py
from rest_framework import status, viewsets
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.db.models import Q
from django.core.mail import send_mail
from django.conf import settings
from django.template.loader import render_to_string
from ..models import Room, RoomGroup, User, UserRoomGroup, AccessLog, Company, InviteToken
from ..serializers import (
    RoomSerializer, RoomGroupSerializer, UserRoomGroupSerializer,
    AccessLogSerializer, UserSerializer, CompanySerializer,
    InviteTokenSerializer, InviteTokenCreateSerializer
)

class AdminPermissionMixin:
    """Mixin to check if user is admin"""
    def check_admin(self, request):
        if not request.user.is_admin:
            return Response({
                'error': 'Admin privileges required'
            }, status=status.HTTP_403_FORBIDDEN)
        return None
        
    def get_company(self, request):
        """Get the company of the current user"""
        return request.user.company

class RoomViewSet(viewsets.ModelViewSet, AdminPermissionMixin):
    """
    ViewSet for Room management (admin only)
    """
    serializer_class = RoomSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Filter rooms by the current user's company"""
        if self.request.user.is_admin:
            return Room.objects.filter(company=self.request.user.company)
        return Room.objects.none()

    def initial(self, request, *args, **kwargs):
        admin_check = self.check_admin(request)
        if admin_check:
            return admin_check
        super().initial(request, *args, **kwargs)
        
    def perform_create(self, serializer):
        """Set the company when creating a new room"""
        serializer.save(company=self.get_company(self.request))

class RoomGroupViewSet(viewsets.ModelViewSet, AdminPermissionMixin):
    """
    ViewSet for RoomGroup management (admin only)
    """
    serializer_class = RoomGroupSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        """Filter room groups by the current user's company"""
        if self.request.user.is_admin:
            return RoomGroup.objects.filter(company=self.request.user.company)
        return RoomGroup.objects.none()

    def initial(self, request, *args, **kwargs):
        admin_check = self.check_admin(request)
        if admin_check:
            return admin_check
        super().initial(request, *args, **kwargs)
        
    def perform_create(self, serializer):
        """Set the company when creating a new room group"""
        serializer.save(company=self.get_company(self.request))

class CompanyViewSet(viewsets.ReadOnlyModelViewSet, AdminPermissionMixin):
    """
    ViewSet for viewing company details (admin only, read-only)
    """
    serializer_class = CompanySerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        if self.request.user.is_admin:
            return Company.objects.filter(id=self.request.user.company.id)
        return Company.objects.none()
    
    def initial(self, request, *args, **kwargs):
        admin_check = self.check_admin(request)
        if admin_check:
            return admin_check
        super().initial(request, *args, **kwargs)

class InviteTokenViewSet(viewsets.ModelViewSet, AdminPermissionMixin):
    """
    ViewSet for managing invite tokens (admin only)
    """
    serializer_class = InviteTokenSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        if self.request.user.is_admin:
            return InviteToken.objects.filter(company=self.request.user.company)
        return InviteToken.objects.none()
    
    def initial(self, request, *args, **kwargs):
        admin_check = self.check_admin(request)
        if admin_check:
            return admin_check
        super().initial(request, *args, **kwargs)
    
    def get_serializer_class(self):
        if self.action == 'create':
            return InviteTokenCreateSerializer
        return InviteTokenSerializer
    
    def perform_create(self, serializer):
        company = self.get_company(self.request)
        token = serializer.save(
            company=company,
            created_by=self.request.user
        )
        
        # Send email with the token
        self.send_invite_email(token)
        
        return token
    
    def send_invite_email(self, token):
        """Send invitation email with token"""
        subject = f"Invitation to join {token.company.name} on BioaccessControl"
        
        # Build the invitation URL
        # In a real deployment, you'd use your domain name
        invitation_url = f"http://localhost:5000/register?token={token.token}"
        
        # Context for the email template
        context = {
            'company_name': token.company.name,
            'role': token.get_role_display(),
            'invitation_url': invitation_url,
            'expiry_date': token.expires_at.strftime('%Y-%m-%d %H:%M'),
            'sender_name': token.created_by.full_name or token.created_by.username,
        }
        
        # You would create an HTML email template in templates/emails/invitation.html
        # html_message = render_to_string('emails/invitation.html', context)
        
        # Plain text fallback
        message = f"""
        You have been invited to join {token.company.name} as a {token.get_role_display()}.
        
        Please use the following link to register:
        {invitation_url}
        
        This invitation expires on {token.expires_at.strftime('%Y-%m-%d %H:%M')}.
        
        Regards,
        {token.created_by.full_name or token.created_by.username}
        """
        
        try:
            # Uncomment when ready to send emails
            # send_mail(
            #     subject,
            #     message,
            #     settings.DEFAULT_FROM_EMAIL,
            #     [token.email],
            #     fail_silently=False,
            #     html_message=html_message,
            # )
            print(f"Email invitation would be sent to {token.email} with token {token.token}")
        except Exception as e:
            print(f"Error sending invitation email: {e}")

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_access_logs(request):
    """
    Get access logs - company-specific logs for admins, user-specific logs for regular users
    """
    user = request.user
    
    # Get query parameters for filtering
    start_date = request.query_params.get('start_date')
    end_date = request.query_params.get('end_date')
    room_id = request.query_params.get('room_id')
    access_status = request.query_params.get('access_status')
    username = request.query_params.get('username')

    # Base queryset - filter by company for admins, by user for regular users
    if user.is_admin:
        logs = AccessLog.objects.filter(company=user.company)
    else:
        logs = AccessLog.objects.filter(user=user, company=user.company)

    # Apply filters
    if start_date:
        logs = logs.filter(timestamp__gte=start_date)
    if end_date:
        logs = logs.filter(timestamp__lte=end_date)
    if room_id:
        logs = logs.filter(room__room_id=room_id)
    if access_status:
        logs = logs.filter(access_granted=(access_status.lower() == 'true'))
    if username and user.is_admin:
        logs = logs.filter(user__username=username)

    # Order by timestamp
    logs = logs.order_by('-timestamp')

    serializer = AccessLogSerializer(logs, many=True)
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_frozen_accounts(request):
    """
    List all frozen accounts (admin only, company-specific)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)

    frozen_users = User.objects.filter(is_frozen=True, company=request.user.company)
    current_time = timezone.now().isoformat()
    
    # Create a list of frozen account data with the expected format
    frozen_accounts = []
    for user in frozen_users:
        # Simplified approach with proper null handling
        try:
            frozen_at = user.frozen_at.isoformat() if user.frozen_at else current_time
        except (AttributeError, ValueError):
            frozen_at = current_time
            
        try:
            full_name = user.full_name if hasattr(user, 'full_name') and user.full_name else user.username
        except AttributeError:
            full_name = user.username
            
        try:
            failed_attempts = user.failed_attempts
        except AttributeError:
            failed_attempts = 3
            
        account_data = {
            'username': user.username,
            'full_name': full_name,
            'failed_attempts': failed_attempts,
            'frozen_at': frozen_at
        }
        frozen_accounts.append(account_data)
    
    return Response(frozen_accounts)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unfreeze_account(request):
    """
    Unfreeze a user account (admin only, company-specific)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)

    username = request.data.get('username')
    if not username:
        return Response({
            'error': 'Username is required'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Only allow unfreezing users from the same company
        user = User.objects.get(username=username, company=request.user.company)
        user.is_frozen = False
        user.failed_attempts = 0
        user.save()
        return Response({
            'message': f'Account {username} has been unfrozen'
        })
    except User.DoesNotExist:
        return Response({
            'error': 'User not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        # Add better error handling
        return Response({
            'error': f'Failed to unfreeze account: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def manage_user_permissions(request):
    """
    Grant or revoke user access to room groups (admin only, company-specific)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)

    username = request.data.get('username')
    group_name = request.data.get('group_name')
    action = request.data.get('action')  # 'grant' or 'revoke'

    if not all([username, group_name, action]) or action not in ['grant', 'revoke']:
        return Response({
            'error': 'Invalid parameters'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Only allow managing users and groups from the same company
        user = User.objects.get(username=username, company=request.user.company)
        group = RoomGroup.objects.get(name=group_name, company=request.user.company)

        if action == 'grant':
            UserRoomGroup.objects.get_or_create(user=user, room_group=group)
            message = f'Access granted to {group_name} for {username}'
        else:  # revoke
            UserRoomGroup.objects.filter(user=user, room_group=group).delete()
            message = f'Access revoked from {group_name} for {username}'

        return Response({'message': message})

    except User.DoesNotExist:
        return Response({
            'error': 'User not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except RoomGroup.DoesNotExist:
        return Response({
            'error': 'Room group not found'
        }, status=status.HTTP_404_NOT_FOUND)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_users(request):
    """
    List all users (admin only, company-specific)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)

    users = User.objects.filter(company=request.user.company)
    serializer = UserSerializer(users, many=True)
    return Response(serializer.data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_permissions(request, username):
    """
    Get all room groups a user has access to (admin only, company-specific)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)
    
    try:
        # Only allow viewing users from the same company
        user = User.objects.get(username=username, company=request.user.company)
        # Get all UserRoomGroup associations for this user
        user_room_groups = UserRoomGroup.objects.filter(user=user)
        
        # Extract the group names
        group_names = [urg.room_group.name for urg in user_room_groups]
        
        return Response({
            'username': username,
            'group_names': group_names
        })
    except User.DoesNotExist:
        return Response({
            'error': 'User not found'
        }, status=status.HTTP_404_NOT_FOUND)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_company_details(request):
    """
    Get details about the current user's company
    """
    company = request.user.company
    if not company:
        return Response({
            'error': 'No company associated with this user'
        }, status=status.HTTP_404_NOT_FOUND)
    
    serializer = CompanySerializer(company)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_invite_token(request):
    """
    Create a new invite token and send it via email (admin only)
    """
    if not request.user.is_admin:
        return Response({
            'error': 'Admin privileges required'
        }, status=status.HTTP_403_FORBIDDEN)
    
    serializer = InviteTokenCreateSerializer(data=request.data)
    if serializer.is_valid():
        # Create token
        token = InviteToken.objects.create(
            email=serializer.validated_data['email'],
            role=serializer.validated_data['role'],
            company=request.user.company,
            created_by=request.user
        )
        
        # Send email with token
        # In a real deployment, uncomment the email sending code in InviteTokenViewSet.send_invite_email
        
        result_serializer = InviteTokenSerializer(token)
        return Response(result_serializer.data, status=status.HTTP_201_CREATED)
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def verify_invite_token(request):
    """
    Verify if an invite token is valid
    """
    token_str = request.data.get('token')
    if not token_str:
        return Response({
            'error': 'Token is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        token = InviteToken.objects.get(token=token_str)
        
        if token.is_expired:
            return Response({
                'valid': False,
                'error': 'Token has expired or already been used'
            })
        
        # Return token details
        return Response({
            'valid': True,
            'token': token.token,
            'email': token.email,
            'role': token.role,
            'company': {
                'id': token.company.id,
                'name': token.company.name
            }
        })
        
    except InviteToken.DoesNotExist:
        return Response({
            'valid': False,
            'error': 'Invalid token'
        })
