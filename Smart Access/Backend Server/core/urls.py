# core/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import auth, admin, test  # Keep test if needed, otherwise remove
# Import new view for user rooms
from .views.room import list_user_rooms  # Add this import

router = DefaultRouter()
# Ensure ViewSet names match the imported classes
router.register(r'rooms', admin.RoomViewSet, basename='room')
router.register(r'room-groups', admin.RoomGroupViewSet, basename='room-group')
router.register(r'company', admin.CompanyViewSet, basename='company')
router.register(r'invite-tokens', admin.InviteTokenViewSet, basename='invite-token')

urlpatterns = [
    # Session/CSRF Helper
    path('auth/csrf/', auth.get_csrf_token_view, name='get-csrf-token'),  # Endpoint to get CSRF token

    # Authentication endpoints (Session based)
    path('auth/register/', auth.register, name='register'),
    path('auth/verify-token/', auth.verify_token, name='verify-token'),
    path('auth/login/step1/', auth.login_step1, name='login-step1'),
    path('auth/login/step2/', auth.login_step2, name='login-step2'),
    path('auth/login/step3/', auth.login_step3, name='login-step3'),
    path('auth/logout/', auth.logout_view, name='logout'),  # Logout endpoint

    # User profile endpoint
    path('user/profile/', auth.get_user_profile, name='user-profile'),

    # User rooms endpoint (for regular users)
    path('user/rooms/', list_user_rooms, name='user-rooms'),  # Add this line and move it up

    # Room access endpoints (Session based)
    path('rooms/access/request/', auth.request_room_access, name='request-room-access'),
    path('rooms/access/face-verify/', auth.room_access_face_verify, name='room-access-face'),
    path('rooms/access/voice-verify/', auth.room_access_voice_verify, name='room-access-voice'),
    path('rooms/<str:room_id>/status/', auth.get_room_status, name='room-status'),
    path('rooms/<str:room_id>/toggle-lock/', auth.toggle_room_lock, name='toggle-room-lock'),

    # Admin management endpoints (Require session authentication)
    path('admin/access-logs/', admin.list_access_logs, name='access-logs'),
    path('admin/frozen-accounts/', admin.list_frozen_accounts, name='frozen-accounts'),
    path('admin/unfreeze-account/', admin.unfreeze_account, name='unfreeze-account'),
    path('admin/user-permissions/', admin.manage_user_permissions, name='manage-permissions'),
    path('admin/user-permissions/<str:username>/', admin.get_user_permissions, name='user-permissions'),
    path('admin/users/', admin.list_users, name='list-users'),
    path('admin/company/', admin.get_company_details, name='company-details'),
    path('admin/create-invite/', admin.create_invite_token, name='create-invite'),

    # Test endpoints (Keep if needed)
    path('test/biometrics/<str:username>/', test.test_biometric_decryption, name='test-biometrics'),

    # ViewSet routes (These are typically admin-focused or list views)
    path('manage/', include(router.urls)),  # Group ViewSet routes under /manage/ prefix
]
