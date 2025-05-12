# core/views/test.py
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import get_user_model
from ..utils import BiometricEncryption
import os
from PIL import Image

User = get_user_model()

@api_view(['GET'])
@permission_classes([IsAdminUser])
def test_biometric_decryption(request, username):
    """
    Test endpoint to verify biometric encryption/decryption
    Only accessible by admin users
    """
    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return Response({
            'error': f'User {username} not found'
        }, status=status.HTTP_404_NOT_FOUND)

    encryption = BiometricEncryption()
    results = {
        'face_image': None,
        'voice_recording': None
    }

    # Test face image
    if user.face_reference_image:
        try:
            decrypted_path = encryption.decrypt_file(user.face_reference_image.path)
            if decrypted_path:
                try:
                    img = Image.open(decrypted_path)
                    img.verify()
                    results['face_image'] = 'Decryption successful'
                except Exception as e:
                    results['face_image'] = f'Image corrupted: {str(e)}'
                finally:
                    os.unlink(decrypted_path)
        except Exception as e:
            results['face_image'] = f'Decryption failed: {str(e)}'

    # Test voice recording
    if user.voice_reference:
        try:
            decrypted_path = encryption.decrypt_file(user.voice_reference.path)
            if decrypted_path:
                try:
                    wav_current = preprocess_wav(decrypted_path)
                    voice_encoder = VoiceEncoder()
                    embedding = voice_encoder.embed_utterance(wav_current)
                    results['voice_recording'] = 'Decryption successful'
                except Exception as e:
                    results['voice_recording'] = f'Recording corrupted: {str(e)}'
                finally:
                    os.unlink(decrypted_path)
        except Exception as e:
            results['voice_recording'] = f'Decryption failed: {str(e)}'

    return Response(results)


