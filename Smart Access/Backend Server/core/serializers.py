# core/serializers.py
from rest_framework import serializers
from .models import User, Room, RoomGroup, AccessLog, UserRoomGroup, Company, InviteToken


# This serializer handles Company model data. It provides fields for company ID, name, and creation date.
# It's used for displaying company information and creating new companies.
class CompanySerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = ('id', 'name', 'created_at')


# This serializer manages InviteToken data, with special handling for company and creator names.
# It distinguishes between read-only fields shown to clients and write-only fields for server processing.
class InviteTokenSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    
    class Meta:
        model = InviteToken
        fields = ('id', 'token', 'email', 'role', 'company', 'company_name',
                 'created_at', 'expires_at', 'is_used', 'created_by', 'created_by_name')
        read_only_fields = ('token', 'created_at', 'is_used', 'used_by')
        extra_kwargs = {
            'company': {'write_only': True},
            'created_by': {'write_only': True},
        }


# This serializer handles User model data, with special handling for company name.
# It hides sensitive fields like passwords and shows user profile information.
class UserSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'phone_number', 'full_name', 'is_admin',
                 'is_frozen', 'frozen_at', 'company', 'company_name')
        extra_kwargs = {
            'password': {'write_only': True},
            'company': {'write_only': True}
        }

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user


# This serializer handles user registration with biometric data. It includes fields for
# face and voice biometric data as well as user credentials and company information.
class RegistrationSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField()
    phone_number = serializers.CharField()
    full_name = serializers.CharField()
    face_image = serializers.FileField()
    voice_recording = serializers.FileField()
    # New fields for company creation or joining
    create_company = serializers.BooleanField(required=False, default=False)
    company_name = serializers.CharField(required=False, allow_blank=True)
    invite_token = serializers.CharField(required=False, allow_blank=True)


# This serializer is used to verify invite tokens during registration.
# It simply requires the token string for verification.
class TokenVerificationSerializer(serializers.Serializer):
    token = serializers.CharField()


# This serializer handles login requests with optional biometric data fields.
# It supports the multi-step login process with credentials, face, and voice verification.
class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField()
    face_image = serializers.FileField(required=False)
    voice_recording = serializers.FileField(required=False)
    challenge_response = serializers.CharField(required=False)


# This serializer manages Room data with additional fields for the associated group and company names.
# It handles creation, update, and display of room information.
class RoomSerializer(serializers.ModelSerializer):
    group_name = serializers.CharField(source='group.name', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)
    
    class Meta:
        model = Room
        fields = '__all__'
        read_only_fields = ('uuid', 'is_unlocked', 'unlock_timestamp')


# This serializer handles RoomGroup data with the company name as an additional field.
# It manages creation, update, and display of room group information.
class RoomGroupSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    
    class Meta:
        model = RoomGroup
        fields = '__all__'


# This serializer manages UserRoomGroup data with additional fields for username and group name.
# It handles the assignment of access permissions between users and room groups.
class UserRoomGroupSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    group_name = serializers.CharField(source='room_group.name', read_only=True)
    
    class Meta:
        model = UserRoomGroup
        fields = '__all__'


# This serializer handles AccessLog data with additional fields for user, room, and company names.
# It's primarily used for displaying access logs in the admin interface and API.
class AccessLogSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    room_name = serializers.CharField(source='room.name', read_only=True)
    room_id = serializers.CharField(source='room.room_id', read_only=True)
    company_name = serializers.CharField(source='company.name', read_only=True)

    class Meta:
        model = AccessLog
        fields = (
            'id', 'username', 'room_name', 'room_id', 'timestamp',
            'access_granted', 'face_spoofing_result', 'speaker_similarity_score',
            'audio_deepfake_result', 'transcription_score', 'failure_reason',
            'company', 'company_name'
        )
        extra_kwargs = {
            'company': {'write_only': True}
        }


# This serializer is specifically for creating new invite tokens.
# It's simpler than the full InviteTokenSerializer, with just the essential fields needed for creation.
class InviteTokenCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = InviteToken
        fields = ('email', 'role', 'company')
