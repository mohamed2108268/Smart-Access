#!/usr/bin/env python
# setup_initial_data.py
import os
import django
import shutil
import tempfile
from django.core.files import File

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'bioaccess_project.settings')
django.setup()

from django.db import transaction
from core.models import Company, User, RoomGroup, Room, UserRoomGroup
from django.contrib.auth.hashers import make_password
from django.conf import settings

def setup_initial_data():
    print("Setting up initial data...")
    
    # Create sample biometric files directory if it doesn't exist
    sample_dir = os.path.join(settings.BASE_DIR, 'sample_biometrics')
    os.makedirs(sample_dir, exist_ok=True)
    
    # Check for sample biometric files
    sample_face = os.path.join(sample_dir, 'sample_face.jpg')
    sample_voice = os.path.join(sample_dir, 'sample_voice.wav')
    
    if not os.path.exists(sample_face):
        # Create a dummy sample face image if it doesn't exist
        print("Warning: Sample face image not found. Creating a placeholder file.")
        print(f"For a real system, please place a real face image at {sample_face}")
        create_placeholder_image(sample_face, 640, 480)
    
    if not os.path.exists(sample_voice):
        # Create a dummy sample voice file if it doesn't exist
        print("Warning: Sample voice recording not found. Creating a placeholder file.")
        print(f"For a real system, please place a real voice recording at {sample_voice}")
        create_placeholder_audio(sample_voice)
    
    try:
        with transaction.atomic():
            # Create default company
            company = Company.objects.create(name="Default Company")
            print(f"Created company: {company.name}")
            
            # Create admin user with biometric references
            admin = User(
                username="admin",
                email="admin@example.com",
                password=make_password("admin123"),  # Set a secure password in production
                phone_number="1234567890",
                full_name="System Administrator",
                is_admin=True,
                is_superuser=True,
                is_staff=True,
                company=company
            )
            
            # Save user first (without files)
            admin.save()
            
            # Add face reference
            with open(sample_face, 'rb') as face_file:
                admin.face_reference_image.save(
                    'admin_face.jpg',
                    File(face_file),
                    save=False
                )
            
            # Add voice reference
            with open(sample_voice, 'rb') as voice_file:
                admin.voice_reference.save(
                    'admin_voice.wav',
                    File(voice_file),
                    save=False
                )
            
            # Save user with files
            admin.save()
            print(f"Created admin user: {admin.username} with biometric data")
            
            # Create a room group
            room_group = RoomGroup.objects.create(
                name="Default Group",
                description="Default room group",
                company=company
            )
            print(f"Created room group: {room_group.name}")
            
            # Create a room
            room = Room.objects.create(
                room_id="ROOM101",
                name="Conference Room 101",
                group=room_group,
                company=company
            )
            print(f"Created room: {room.name}")
            
            # Grant admin access to the room group
            UserRoomGroup.objects.create(
                user=admin,
                room_group=room_group
            )
            print(f"Granted admin access to {room_group.name}")
            
            print("Initial data setup complete!")
            
    except Exception as e:
        print(f"Error setting up initial data: {e}")
        return False
    
    return True

def create_placeholder_image(filepath, width=640, height=480):
    """Create a simple placeholder image file"""
    try:
        # Try to use PIL if available
        from PIL import Image, ImageDraw, ImageFont
        
        img = Image.new('RGB', (width, height), color=(73, 109, 137))
        d = ImageDraw.Draw(img)
        
        # Try to add text
        try:
            font = ImageFont.truetype("arial.ttf", 36)
            d.text((width//4, height//2), "Sample Face Image", fill=(255, 255, 255), font=font)
        except:
            # If no font is available, just use default
            d.text((width//4, height//2), "Sample Face Image", fill=(255, 255, 255))
            
        img.save(filepath)
        
    except ImportError:
        # If PIL is not available, create an empty file
        with open(filepath, 'wb') as f:
            # Create a minimal JPEG file
            f.write(bytes([
                0xFF, 0xD8,                   # SOI marker
                0xFF, 0xE0, 0x00, 0x10,       # APP0 marker
                0x4A, 0x46, 0x49, 0x46, 0x00, # JFIF identifier
                0x01, 0x01,                   # version
                0x00,                         # units
                0x00, 0x01, 0x00, 0x01,       # density
                0x00, 0x00,                   # thumbnail
                0xFF, 0xD9                    # EOI marker
            ]))
    
    print(f"Created placeholder image at {filepath}")

def create_placeholder_audio(filepath):
    """Create a simple placeholder WAV file"""
    try:
        # Try to use numpy/scipy if available
        import numpy as np
        from scipy.io import wavfile
        
        # Create a 3-second silence at 16kHz
        sample_rate = 16000
        duration = 3  # seconds
        samples = np.zeros(sample_rate * duration, dtype=np.int16)
        
        # Add a simple sine wave tone
        t = np.linspace(0, duration, sample_rate * duration)
        samples += (10000 * np.sin(2 * np.pi * 440 * t)).astype(np.int16)  # 440 Hz tone
        
        wavfile.write(filepath, sample_rate, samples)
        
    except ImportError:
        # If numpy/scipy not available, create an empty WAV file
        with open(filepath, 'wb') as f:
            # Create a minimal WAV file header (44 bytes)
            # RIFF header
            f.write(b'RIFF')
            f.write((36).to_bytes(4, byteorder='little'))  # file size - 8
            f.write(b'WAVE')
            
            # fmt chunk
            f.write(b'fmt ')
            f.write((16).to_bytes(4, byteorder='little'))  # fmt chunk size
            f.write((1).to_bytes(2, byteorder='little'))   # format = PCM
            f.write((1).to_bytes(2, byteorder='little'))   # channels = 1
            f.write((16000).to_bytes(4, byteorder='little'))  # sample rate
            f.write((32000).to_bytes(4, byteorder='little'))  # byte rate
            f.write((2).to_bytes(2, byteorder='little'))   # block align
            f.write((16).to_bytes(2, byteorder='little'))  # bits per sample
            
            # data chunk
            f.write(b'data')
            f.write((0).to_bytes(4, byteorder='little'))  # data size
    
    print(f"Created placeholder audio at {filepath}")

if __name__ == "__main__":
    setup_initial_data()
