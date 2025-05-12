# core/management/commands/test_biometrics.py
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from core.utils import BiometricEncryption, BiometricVerification
import os
import tempfile
from PIL import Image
from resemblyzer import VoiceEncoder, preprocess_wav



User = get_user_model()

class Command(BaseCommand):
    help = 'Test biometric encryption/decryption for a specific user'

    def add_arguments(self, parser):
        parser.add_argument('username', type=str, help='Username to test')

    def handle(self, *args, **kwargs):
        username = kwargs['username']
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'User {username} not found'))
            return

        encryption = BiometricEncryption()
        
        # Test face image
        if user.face_reference_image:
            try:
                # Try to decrypt
                decrypted_path = encryption.decrypt_file(user.face_reference_image.path)
                if decrypted_path:
                    # Try to open the image to verify it's valid
                    try:
                        img = Image.open(decrypted_path)
                        img.verify()
                        self.stdout.write(
                            self.style.SUCCESS(f'Face image decryption successful for {username}')
                        )
                    except Exception as e:
                        self.stdout.write(
                            self.style.ERROR(f'Face image is corrupted: {e}')
                        )
                    finally:
                        os.unlink(decrypted_path)
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Face image decryption failed: {e}')
                )

        # Test voice recording
        if user.voice_reference:
            try:
                # Try to decrypt
                decrypted_path = encryption.decrypt_file(user.voice_reference.path)
                if decrypted_path:
                    try:
                        # Try to use it with the voice verifier
                        wav_current = preprocess_wav(decrypted_path)
                        voice_encoder = VoiceEncoder()
                        embedding = voice_encoder.embed_utterance(wav_current)
                        self.stdout.write(
                            self.style.SUCCESS(f'Voice recording decryption successful for {username}')
                        )
                    except Exception as e:
                        self.stdout.write(
                            self.style.ERROR(f'Voice recording is corrupted: {e}')
                        )
                    finally:
                        os.unlink(decrypted_path)
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Voice recording decryption failed: {e}')
                )

