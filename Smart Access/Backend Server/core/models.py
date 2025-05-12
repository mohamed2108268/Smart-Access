# core/models.py
from django.contrib.auth.models import AbstractUser
from django.db import models
import os
from django.conf import settings
from cryptography.fernet import Fernet
import base64
from .utils import BiometricEncryption
import uuid as uuid_lib
from django.utils import timezone
import secrets

# This function creates a secure path for storing biometric data files. It takes the user instance and original filename,
# generates a unique filename using the user's username and a random token, and returns the path where the file should be saved.
def get_biometric_path(instance, filename):
    ext = filename.split('.')[-1]
    filename = f"{instance.username}_{base64.urlsafe_b64encode(os.urandom(8)).decode()}.{ext}"
    return os.path.join('biometric_data', instance.username, filename)

# Company model represents an organization in our multi-tenant system. Each company has a unique name and
# can have multiple users, rooms, and access logs associated with it.
class Company(models.Model):
    name = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return self.name

# InviteToken model handles the invitation process for new users. It stores a unique token linked to an email address
# and company, with an expiration date and information about who created it and who used it. Tokens can be for either
# admin or regular user roles.
class InviteToken(models.Model):
    ROLE_CHOICES = [
        ('admin', 'Administrator'),
        ('user', 'Regular User'),
    ]
    
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='invite_tokens')
    token = models.CharField(max_length=64, unique=True)
    email = models.EmailField()
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='user')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)
    used_by = models.ForeignKey('User', on_delete=models.SET_NULL, null=True, blank=True, related_name='used_token')
    created_by = models.ForeignKey('User', on_delete=models.SET_NULL, null=True, related_name='created_tokens')
    
    def __str__(self):
        return f"Invite to {self.email} for {self.company.name} ({self.role})"
    
    def save(self, *args, **kwargs):
        # Generate token if this is a new instance
        if not self.token:
            self.token = secrets.token_urlsafe(32)
        
        # Set expiration time if not set (default 7 days)
        if not self.expires_at:
            self.expires_at = timezone.now() + timezone.timedelta(days=7)
            
        super().save(*args, **kwargs)
    
    @property
    def is_expired(self):
        return timezone.now() > self.expires_at or self.is_used
    
    @property
    def is_valid(self):
        return not self.is_expired

# User model extends Django's AbstractUser to add biometric authentication capabilities. It stores references to
# face and voice data, tracks security status (failed attempts, account freezing), and links users to companies.
class User(AbstractUser):
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=15)
    full_name = models.CharField(max_length=255)
    face_reference_image = models.FileField(upload_to=get_biometric_path, null=True, blank=True)
    voice_reference = models.FileField(upload_to=get_biometric_path, null=True, blank=True)
    is_frozen = models.BooleanField(default=False)
    frozen_at = models.DateTimeField(null=True, blank=True)
    failed_attempts = models.IntegerField(default=0)
    is_admin = models.BooleanField(default=False)
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='users', null=True, blank=True)

    def __str__(self):
        return self.username
        
    def save(self, *args, **kwargs):
        # Check if there's a new face image or voice recording to encrypt
        is_new_face = self._state.adding or (
            self.face_reference_image and
            hasattr(self.face_reference_image, 'file')
        )
        is_new_voice = self._state.adding or (
            self.voice_reference and
            hasattr(self.voice_reference, 'file')
        )
        
        # Save model first
        super().save(*args, **kwargs)
        
        # Encrypt new biometric files after saving
        encryption = BiometricEncryption()
        
        if is_new_face and self.face_reference_image:
            try:
                encryption.encrypt_file(self.face_reference_image.path)
            except Exception as e:
                print(f"Error encrypting face reference: {e}")
                
        if is_new_voice and self.voice_reference:
            try:
                encryption.encrypt_file(self.voice_reference.path)
            except Exception as e:
                print(f"Error encrypting voice reference: {e}")
                
    def delete(self, *args, **kwargs):
        # Clean up biometric files when deleting user
        if self.face_reference_image:
            try:
                os.remove(self.face_reference_image.path)
            except Exception as e:
                print(f"Error deleting face reference: {e}")
                
        if self.voice_reference:
            try:
                os.remove(self.voice_reference.path)
            except Exception as e:
                print(f"Error deleting voice reference: {e}")
                
        super().delete(*args, **kwargs)

# RoomGroup model provides a way to organize rooms logically and assign access permissions efficiently.
# Rooms in the same group can share access permissions, making it easier to manage who can access multiple rooms.
class RoomGroup(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='room_groups', null=True, blank=True)

    def __str__(self):
        return self.name
    
    class Meta:
        unique_together = ('name', 'company')

# Room model represents a physical space controlled by the system. Each room has a unique ID that is used by
# the hardware controller (ESP32), a name, and belongs to both a company and a room group.
class Room(models.Model):
    room_id = models.CharField(max_length=50)
    name = models.CharField(max_length=255)
    is_unlocked = models.BooleanField(default=False)
    unlock_timestamp = models.DateTimeField(null=True, blank=True)
    group = models.ForeignKey(RoomGroup, on_delete=models.CASCADE, related_name='rooms')
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='rooms', null=True, blank=True)

    def __str__(self):
        return f"{self.name} ({self.room_id})"
    
    class Meta:
        unique_together = ('room_id', 'company')

# UserRoomGroup is a junction model that links users to room groups, defining access permissions.
# Each entry gives a specific user access to all rooms in a specific room group.
class UserRoomGroup(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='allowed_room_groups')
    room_group = models.ForeignKey(RoomGroup, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('user', 'room_group')

    def __str__(self):
        return f"{self.user.username} - {self.room_group.name}"

# AccessLog model records all access attempts, whether successful or failed. It includes details about
# the biometric verification results, helping with security auditing and troubleshooting.
class AccessLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    room = models.ForeignKey(Room, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    access_granted = models.BooleanField()
    face_spoofing_result = models.CharField(max_length=50)  # genuine/spoofed
    speaker_similarity_score = models.FloatField()
    audio_deepfake_result = models.IntegerField()  # 0 for deepfake, 1 for genuine
    transcription_score = models.FloatField()
    failure_reason = models.CharField(max_length=255, null=True, blank=True)
    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name='access_logs', null=True, blank=True)

    def __str__(self):
        return f"{self.user.username} - {self.room.room_id} - {'Granted' if self.access_granted else 'Denied'}"

# Create directories for biometric data
os.makedirs(settings.BIOMETRIC_ROOT, exist_ok=True)
