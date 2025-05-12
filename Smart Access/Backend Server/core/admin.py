# core/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html
from .models import User, Room, RoomGroup, UserRoomGroup, AccessLog, Company, InviteToken
from django.utils import timezone

# The CompanyAdmin class customizes how Company objects are displayed in the Django admin interface.
# It shows company name, creation date, and counts of associated users and rooms.
@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at', 'get_users_count', 'get_rooms_count')
    search_fields = ('name',)
    ordering = ('name',)

    def get_users_count(self, obj):
        return obj.users.count()
    get_users_count.short_description = 'Number of Users'

    def get_rooms_count(self, obj):
        return obj.rooms.count()
    get_rooms_count.short_description = 'Number of Rooms'

# The InviteTokenAdmin class manages invitation tokens in the admin interface.
# It displays token info including email, role, company, expiration, and status,
# with color-coded status indicators.
@admin.register(InviteToken)
class InviteTokenAdmin(admin.ModelAdmin):
    list_display = ('email', 'role', 'company', 'created_by', 'created_at', 'expires_at', 'is_used', 'status')
    list_filter = ('company', 'role', 'is_used', 'created_at')
    search_fields = ('email', 'token', 'company__name', 'created_by__username')
    readonly_fields = ('token', 'created_at', 'is_expired')
    ordering = ('-created_at',)
    
    fieldsets = (
        (None, {'fields': ('email', 'role', 'company', 'created_by')}),
        ('Token Information', {'fields': ('token', 'created_at', 'expires_at', 'is_used', 'used_by')}),
    )
    
    def status(self, obj):
        if obj.is_used:
            return format_html('<span style="color: blue;">Used</span>')
        elif obj.is_expired:
            return format_html('<span style="color: red;">Expired</span>')
        else:
            return format_html('<span style="color: green;">Valid</span>')
    status.short_description = 'Status'
    
    def save_model(self, request, obj, form, change):
        if not change:  # Only for new tokens
            if not obj.created_by:
                obj.created_by = request.user
            if not obj.expires_at:
                obj.expires_at = timezone.now() + timezone.timedelta(days=7)
        super().save_model(request, obj, form, change)

# The CustomUserAdmin class extends Django's UserAdmin to handle our custom User model.
# It includes additional fields like biometric data references, security info, and company association.
@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'full_name', 'company', 'is_admin', 'is_frozen', 'failed_attempts')
    list_filter = ('company', 'is_admin', 'is_frozen', 'is_active')
    search_fields = ('username', 'email', 'full_name', 'company__name')
    ordering = ('username',)
    
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal Info', {'fields': ('email', 'full_name', 'phone_number', 'company')}),
        ('Biometric Data', {'fields': ('face_reference_image', 'voice_reference')}),
        ('Security', {'fields': ('is_frozen', 'frozen_at', 'failed_attempts')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_admin', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2', 'full_name', 'phone_number', 'company'),
        }),
    )

    def has_delete_permission(self, request, obj=None):
        # Prevent deletion of users to maintain access logs integrity
        return False

# The RoomAdmin class customizes how Room objects are displayed in the admin interface.
# It shows room ID, name, group, and company, with filtering and searching capabilities.
@admin.register(Room)
class RoomAdmin(admin.ModelAdmin):
    list_display = ('room_id', 'name', 'group', 'company')
    list_filter = ('group', 'company')
    search_fields = ('room_id', 'name', 'company__name')
    ordering = ('room_id',)

# The RoomGroupAdmin class manages room groups in the admin interface.
# It displays group details and counts of associated rooms and users.
