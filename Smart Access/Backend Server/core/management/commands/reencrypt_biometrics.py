# core/management/commands/reencrypt_biometrics.py
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from core.utils import BiometricEncryption
import os
import tempfile
from django.core.files import File

User = get_user_model()

class Command(BaseCommand):
    help = 'Re-encrypts all biometric files with current key'

    def handle(self, *args, **options):
        encryption = BiometricEncryption()
        users = User.objects.all()
        
        for user in users:
            if user.face_reference_image:
                try:
                    # Create a temporary copy of the original file
                    temp_path = None
                    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                        with open(user.face_reference_image.path, 'rb') as original:
                            temp_file.write(original.read())
                        temp_path = temp_file.name
                    
                    # Re-encrypt the file
                    encryption.encrypt_file(temp_path)
                    
                    # Save back to user model
                    with open(temp_path, 'rb') as encrypted_file:
                        user.face_reference_image.save(
                            os.path.basename(user.face_reference_image.name),
                            File(encrypted_file),
                            save=True
                        )
                    
                    if temp_path:
                        os.unlink(temp_path)
                        
                    self.stdout.write(
                        self.style.SUCCESS(f'Re-encrypted face reference for user {user.username}')
                    )
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(f'Error re-encrypting face reference for {user.username}: {e}')
                    )
            
            if user.voice_reference:
                try:
                    # Create a temporary copy of the original file
                    temp_path = None
                    with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                        with open(user.voice_reference.path, 'rb') as original:
                            temp_file.write(original.read())
                        temp_path = temp_file.name
                    
                    # Re-encrypt the file
                    encryption.encrypt_file(temp_path)
                    
                    # Save back to user model
                    with open(temp_path, 'rb') as encrypted_file:
                        user.voice_reference.save(
                            os.path.basename(user.voice_reference.name),
                            File(encrypted_file),
                            save=True
                        )
                    
                    if temp_path:
                        os.unlink(temp_path)
                        
                    self.stdout.write(
                        self.style.SUCCESS(f'Re-encrypted voice reference for user {user.username}')
                    )
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(f'Error re-encrypting voice reference for {user.username}: {e}')
                    )
