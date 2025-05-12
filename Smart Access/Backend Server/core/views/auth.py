# core/views/auth.py
import tempfile
import os
from django.core.files import File
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import authenticate, login as django_login, logout as django_logout
from django.middleware.csrf import get_token
from django.utils import timezone
from rest_framework.authentication import SessionAuthentication

from ..models import User, AccessLog, Room, Company, InviteToken
from ..utils import BiometricVerification, BiometricEncryption, AuthenticationTimer
from ..serializers import RegistrationSerializer, LoginSerializer, UserSerializer, TokenVerificationSerializer


biometric_verifier = BiometricVerification()
biometric_encryption = BiometricEncryption()

# Helper function to handle failed attempts and freezing
def handle_failed_attempt(user):
    user.failed_attempts += 1
    if user.failed_attempts >= 3:
        user.is_frozen = True
        user.frozen_at = timezone.now() # Set frozen timestamp
    user.save()
    return 3 - user.failed_attempts

@api_view(['GET'])
@permission_classes([AllowAny])
def get_csrf_token_view(request):
    """
    Provides the CSRF token to the frontend.
    Should be called first by the frontend to get the token for subsequent POST requests.
    """
    return Response({'csrfToken': get_token(request)})


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_token(request):
    """
    Verify an invite token before registration
    """
    serializer = TokenVerificationSerializer(data=request.data)
    if not serializer.is_valid():
        return Response({
            'error': 'Token is required'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    token_str = serializer.validated_data['token']
    
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


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """
    Register a new user with biometric data and company association
    """
    serializer = RegistrationSerializer(data=request.data)
    if not serializer.is_valid():
        # Extract and format field errors if available
        field_errors = {field: [str(err) for err in errors] for field, errors in serializer.errors.items()}
        return Response({
            'error': 'Invalid registration data',
            'errors': field_errors
        }, status=status.HTTP_400_BAD_REQUEST)

    # Check if username or email already exists (more specific errors)
    if User.objects.filter(username=serializer.validated_data['username']).exists():
         return Response({
            'error': 'Registration failed',
            'errors': {'username': ['Username already exists.']}
         }, status=status.HTTP_400_BAD_REQUEST)
    if User.objects.filter(email=serializer.validated_data['email']).exists():
         return Response({
            'error': 'Registration failed',
            'errors': {'email': ['Email already exists.']}
         }, status=status.HTTP_400_BAD_REQUEST)

    # Process company creation or invitation
    company = None
    invite_token = None
    is_admin = False
    
    # Check if using an invite token
    if serializer.validated_data.get('invite_token'):
        token_str = serializer.validated_data.get('invite_token')
        try:
            invite_token = InviteToken.objects.get(token=token_str)
            
            if invite_token.is_expired:
                return Response({
                    'error': 'Registration failed',
                    'errors': {'invite_token': ['Invite token has expired or already been used.']}
                }, status=status.HTTP_400_BAD_REQUEST)
                
            # Validate email matches token
            if invite_token.email != serializer.validated_data['email']:
                return Response({
                    'error': 'Registration failed',
                    'errors': {'email': ['Email does not match the invitation.']}
                }, status=status.HTTP_400_BAD_REQUEST)
                
            company = invite_token.company
            is_admin = (invite_token.role == 'admin')
            
        except InviteToken.DoesNotExist:
            return Response({
                'error': 'Registration failed',
                'errors': {'invite_token': ['Invalid invite token.']}
            }, status=status.HTTP_400_BAD_REQUEST)
    
    # Check if creating a new company
    elif serializer.validated_data.get('create_company', False):
        company_name = serializer.validated_data.get('company_name')
        if not company_name:
            return Response({
                'error': 'Registration failed',
                'errors': {'company_name': ['Company name is required when creating a new company.']}
            }, status=status.HTTP_400_BAD_REQUEST)
            
        # Check if company name already exists
        if Company.objects.filter(name=company_name).exists():
            return Response({
                'error': 'Registration failed',
                'errors': {'company_name': ['Company name already exists.']}
            }, status=status.HTTP_400_BAD_REQUEST)
            
        # Create new company
        company = Company.objects.create(name=company_name)
        is_admin = True  # First user of a company is an admin
        
    else:
        # Neither creating company nor using invite token
        return Response({
            'error': 'Registration failed',
            'errors': {'non_field_errors': ['Either create a new company or provide an invite token.']}
        }, status=status.HTTP_400_BAD_REQUEST)

    user = None # Initialize user to None
    try:
        # Create user
        user_data = {
            'username': serializer.validated_data['username'],
            'email': serializer.validated_data['email'],
            'phone_number': serializer.validated_data['phone_number'],
            'full_name': serializer.validated_data['full_name'],
            'is_admin': is_admin,
            'company': company
        }
        user = User.objects.create_user(
            password=serializer.validated_data['password'],
            **user_data
        )
        user.save() # Ensure user is saved before file operations

        # Process and encrypt face reference
        face_image = request.FILES.get('face_image')
        if not face_image:
            raise ValueError("Face image is required.")

        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_file:
            for chunk in face_image.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        # Encrypt face image before saving
        if not biometric_encryption.encrypt_file(temp_path):
             raise Exception("Failed to encrypt face image.")
        with open(temp_path, 'rb') as encrypted_file:
            user.face_reference_image.save(
                f"{user.username}_face.jpg",
                File(encrypted_file),
                save=False # Don't save the user model again yet
            )
        os.unlink(temp_path)

        # Process and encrypt voice reference
        voice_recording = request.FILES.get('voice_recording')
        if not voice_recording:
             raise ValueError("Voice recording is required.")

        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            for chunk in voice_recording.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        # Encrypt voice recording before saving
        if not biometric_encryption.encrypt_file(temp_path):
             raise Exception("Failed to encrypt voice recording.")
        with open(temp_path, 'rb') as encrypted_file:
            user.voice_reference.save(
                f"{user.username}_voice.wav",
                File(encrypted_file),
                save=False # Don't save the user model again yet
            )
        os.unlink(temp_path)

        # Save the user model with the file paths attached
        user.save()
        
        # Mark invite token as used if applicable
        if invite_token:
            invite_token.is_used = True
            invite_token.used_by = user
            invite_token.save()

        # Serialize the created user data (excluding sensitive info)
        response_user_data = UserSerializer(user).data

        return Response({
            'message': 'User registered successfully',
            'user': response_user_data
        }, status=status.HTTP_201_CREATED)

    except Exception as e:
        # Clean up user and files if registration fails mid-way
        if user and user.pk: # Check if user object was created and has a PK
            # Attempt to delete files only if they were associated
            if user.face_reference_image and hasattr(user.face_reference_image, 'path') and os.path.exists(user.face_reference_image.path):
                try:
                    os.unlink(user.face_reference_image.path)
                except OSError:
                    pass # Ignore if deletion fails
            if user.voice_reference and hasattr(user.voice_reference, 'path') and os.path.exists(user.voice_reference.path):
                 try:
                    os.unlink(user.voice_reference.path)
                 except OSError:
                    pass # Ignore if deletion fails
            user.delete() # Delete the user record

        # Check for specific ValueErrors from file checks
        error_detail = str(e)
        error_fields = {}
        if "Face image is required" in error_detail:
            error_fields['face_image'] = [error_detail]
        elif "Voice recording is required" in error_detail:
             error_fields['voice_recording'] = [error_detail]

        return Response({
            'error': f'Registration failed: {error_detail}',
            'errors': error_fields if error_fields else None
        }, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([AllowAny])
def login_step1(request):
    """
    First step of login: validate credentials.
    Establishes session context but doesn't fully log in yet.
    """
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({
            'error': 'Please provide both username and password'
        }, status=status.HTTP_400_BAD_REQUEST)

    # Use authenticate to check credentials without logging in
    user = authenticate(request, username=username, password=password)

    if not user:
        # Check if user exists to provide a hint about freezing or bad password
        try:
            existing_user = User.objects.get(username=username)
            if existing_user.is_frozen:
                 return Response({
                    'error': 'Account is frozen. Please contact administrator.'
                 }, status=status.HTTP_403_FORBIDDEN)
            else:
                 # Increment failed attempts for existing, non-frozen user with bad password
                 attempts_remaining = handle_failed_attempt(existing_user)
                 return Response({
                    'error': 'Invalid credentials.',
                    'attempts_remaining': attempts_remaining,
                    'is_frozen': existing_user.is_frozen
                 }, status=status.HTTP_401_UNAUTHORIZED)
        except User.DoesNotExist:
            # User doesn't exist
             return Response({
                'error': 'Invalid credentials.'
             }, status=status.HTTP_401_UNAUTHORIZED)

    # User exists and password is correct, check if frozen
    if user.is_frozen:
        return Response({
            'error': 'Account is frozen. Please contact administrator.'
        }, status=status.HTTP_403_FORBIDDEN)

    # Store username in session for next steps - session starts here
    request.session['login_username'] = username
    request.session['login_step'] = 1 # Track progress
    
    request.session.save()


    # Start the timer for the face step
    face_timeout = AuthenticationTimer.start_timer(request, 'face')

    response = Response({
        'message': 'Credentials verified. Proceed with face verification.',
        'next_step': 'face_verification',
        'remaining_time': face_timeout, # Provide initial time for face step
        'csrfToken': get_token(request), # Provide CSRF token for subsequent POSTs
        'session_token': request.session.session_key,

    })
    
    return response


@api_view(['POST'])
@permission_classes([AllowAny]) # AllowAny because session might not be fully authenticated yet
def login_step2(request):
    """
    Second step of login: face verification with timer.
    Requires a valid session started in step 1.
    """
    username = request.session.get('login_username')
    
    if not username:
        username = request.data.get('username')
    if not username:
        username = request.query_params.get('username')
    if not username:
        username = request.headers.get('X-Username')
        
    print(f"Login step 2 - Username sources: session={request.session.get('login_username')}, data={request.data.get('username')}, query={request.query_params.get('username')}")
    
    current_step = request.session.get('login_step')

    if not username or current_step != 1:
        return Response({
            'error': 'Invalid session state. Please start login process again.'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(username=username)
        if user.is_frozen: # Double check in case status changed
            request.session.flush() # Clear potentially invalid session
            return Response({'error': 'Account is frozen.'}, status=status.HTTP_403_FORBIDDEN)

    except User.DoesNotExist:
         request.session.flush()
         return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)


    # Check timer status
    is_valid, remaining_time = AuthenticationTimer.check_timer(request, 'face')
    if not is_valid:
        attempts_remaining = handle_failed_attempt(user)
        AuthenticationTimer.clear_timer(request, 'face')
        request.session.pop('login_step', None) # Reset step progress

        return Response({
            'error': 'Face verification timeout',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen
        }, status=status.HTTP_408_REQUEST_TIMEOUT)

    # Get the face image from the request
    face_image = request.FILES.get('face_image')
    if not face_image:
        return Response({
            'error': 'Face image required',
            'remaining_time': remaining_time # Inform client how much time is left
        }, status=status.HTTP_400_BAD_REQUEST)

    # Save the face image temporarily
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_file:
            for chunk in face_image.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        # Verify the face image against the reference
        if not user.face_reference_image:
             return Response({'error': 'Face reference data not found for user.'}, status=status.HTTP_400_BAD_REQUEST)

        face_verified = biometric_verifier.verify_face(
            temp_path,
            user.face_reference_image.path
        )
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path) # Ensure cleanup

    if not face_verified:
        attempts_remaining = handle_failed_attempt(user)
        # Keep session active for retry, don't clear timer or step yet
        return Response({
            'error': 'Face verification failed',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time # Still show remaining time for this attempt
        }, status=status.HTTP_401_UNAUTHORIZED)

    # Face verified successfully!
    AuthenticationTimer.clear_timer(request, 'face')
    request.session['login_step'] = 2 # Update progress

    # Start the voice timer
    voice_timeout = AuthenticationTimer.start_timer(request, 'voice')

    # Fetch the challenge sentence for voice verification
    challenge_sentence = biometric_verifier.get_challenge_sentence()
    request.session['challenge_sentence'] = challenge_sentence

    return Response({
        'message': 'Face verified. Proceed with voice verification.',
        'challenge_sentence': challenge_sentence,
        'next_step': 'voice_verification',
        'remaining_time': voice_timeout # Provide time for voice step
    })


@api_view(['POST'])
@permission_classes([AllowAny]) # AllowAny because session might not be fully authenticated yet
def login_step3(request):
    """
    Final step of login: voice verification with timer.
    Requires a valid session from step 2.
    Logs the user in fully on success.
    """
    username = request.session.get('login_username')
    challenge_sentence = request.session.get('challenge_sentence')
    current_step = request.session.get('login_step')

    if not username or not challenge_sentence or current_step != 2:
        return Response({
            'error': 'Invalid session state. Please start login process again.'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(username=username)
        if user.is_frozen:
            request.session.flush()
            return Response({'error': 'Account is frozen.'}, status=status.HTTP_403_FORBIDDEN)
    except User.DoesNotExist:
         request.session.flush()
         return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

    # Check timer
    is_valid, remaining_time = AuthenticationTimer.check_timer(request, 'voice')
    if not is_valid:
        attempts_remaining = handle_failed_attempt(user)
        AuthenticationTimer.clear_timer(request, 'voice')
        request.session.pop('login_step', None) # Reset step progress

        return Response({
            'error': 'Voice verification timeout',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen
        }, status=status.HTTP_408_REQUEST_TIMEOUT)

    voice_recording = request.FILES.get('voice_recording')
    if not voice_recording:
        return Response({
            'error': 'Voice recording required',
            'remaining_time': remaining_time
        }, status=status.HTTP_400_BAD_REQUEST)

    # Save voice recording temporarily
    temp_path = None
    voice_result = None
    try:
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            for chunk in voice_recording.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        # Verify voice
        if not user.voice_reference:
             return Response({'error': 'Voice reference data not found for user.'}, status=status.HTTP_400_BAD_REQUEST)

        voice_result = biometric_verifier.verify_voice(
            temp_path,
            user.voice_reference.path,
            challenge_sentence
        )
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path) # Ensure cleanup


    if not voice_result:
        attempts_remaining = handle_failed_attempt(user)
        return Response({
            'error': 'Voice verification processing failed', # More specific internal error
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR) # Indicate server-side issue

    # Check verification thresholds
    threshold_passed = (
        voice_result['speaker_similarity'] >= 0.69 and
        voice_result['transcription_similarity'] >= 0.7 and
        voice_result['is_genuine_audio']
    )

    if not threshold_passed:
        attempts_remaining = handle_failed_attempt(user)
        # Log detailed failure reasons if needed
        failure_details = f"Speaker: {voice_result['speaker_similarity']:.2f}, Transcription: {voice_result['transcription_similarity']:.2f}, Genuine: {voice_result['is_genuine_audio']}"
        print(f"Voice verification failed for {username}: {failure_details}") # Log for admin

        return Response({
            'error': 'Voice verification failed',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time
        }, status=status.HTTP_401_UNAUTHORIZED)

    # --- Login Successful ---
    user.failed_attempts = 0 # Reset counter
    user.save()

    # Perform actual login using Django's session framework
    django_login(request, user) # This sets the session cookie properly

    # Clear temporary login session data
    AuthenticationTimer.clear_timer(request, 'voice')
    request.session.pop('login_username', None)
    request.session.pop('challenge_sentence', None)
    request.session.pop('login_step', None)

    # Return user information
    serializer = UserSerializer(user)
    return Response({
        'message': 'Login successful',
        'user': serializer.data
        # No tokens needed for session authentication
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated]) # Now requires a valid, logged-in session
@authentication_classes([SessionAuthentication]) # Explicitly state session auth
def logout_view(request):
    """
    Logs the user out by clearing the Django session.
    """
    django_logout(request) # Clears the session data and cookie
    return Response({'message': 'Logout successful'}, status=status.HTTP_200_OK)


# --- Room Access Views (Using Session Authentication) ---

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([SessionAuthentication])
def request_room_access(request):
    """
    Initial step for room access: verify room permission.
    Relies on the existing authenticated session.
    """
    room_id = request.data.get('room_id')
    if not room_id:
        return Response({
            'error': 'Room ID is required'
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Only allow accessing rooms in the user's company
        room = Room.objects.get(room_id=room_id, company=request.user.company)
    except Room.DoesNotExist:
        return Response({
            'error': 'Room not found'
        }, status=status.HTTP_404_NOT_FOUND)

    user = request.user # request.user is available due to SessionAuthentication
    if user.is_frozen:
        return Response({
            'error': 'Account is frozen'
        }, status=status.HTTP_403_FORBIDDEN)

    # Check if user has permission for this room's group
    # Ensure related_name 'allowed_room_groups' matches UserRoomGroup model
    if not user.allowed_room_groups.filter(room_group=room.group).exists():
        # Log the failed attempt
        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='not_attempted',
            speaker_similarity_score=0,
            audio_deepfake_result=0,
            transcription_score=0,
            failure_reason='Permission denied for room group'
        )
        return Response({
            'error': 'Permission denied for this room'
        }, status=status.HTTP_403_FORBIDDEN)

    # Permission OK, store room_id in session for next steps
    request.session['access_room_id'] = room_id
    request.session['access_step'] = 1

    # Start face timer for room access
    face_timeout = AuthenticationTimer.start_timer(request, 'face')

    return Response({
        'message': 'Permission verified. Proceed with face verification.',
        'next_step': 'face_verification',
        'remaining_time': face_timeout
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([SessionAuthentication])
def room_access_face_verify(request):
    """Second step for room access: face verification with timer"""
    room_id = request.session.get('access_room_id')
    current_step = request.session.get('access_step')

    if not room_id or current_step != 1:
        return Response({
            'error': 'Invalid session state. Please start room access process again.'
        }, status=status.HTTP_400_BAD_REQUEST)

    user = request.user
    try:
        # Only allow accessing rooms in the user's company
        room = Room.objects.get(room_id=room_id, company=user.company)
    except Room.DoesNotExist:
         # Clean up session if room disappears mid-flow?
         request.session.pop('access_room_id', None)
         request.session.pop('access_step', None)
         AuthenticationTimer.clear_timer(request, 'face')
         return Response({'error': 'Room not found'}, status=status.HTTP_404_NOT_FOUND)

    if user.is_frozen: # Re-check frozen status
        return Response({'error': 'Account is frozen'}, status=status.HTTP_403_FORBIDDEN)

    # Check timer
    is_valid, remaining_time = AuthenticationTimer.check_timer(request, 'face')
    if not is_valid:
        attempts_remaining = handle_failed_attempt(user) # Use helper
        request.session.pop('access_step', None) # Reset progress

        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='timeout',
            speaker_similarity_score=0,
            audio_deepfake_result=0,
            transcription_score=0,
            failure_reason='Face verification timeout'
        )
        AuthenticationTimer.clear_timer(request, 'face')
        return Response({
            'error': 'Face verification timeout',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen
        }, status=status.HTTP_408_REQUEST_TIMEOUT)

    face_image = request.FILES.get('face_image')
    if not face_image:
        return Response({
            'error': 'Face image required',
            'remaining_time': remaining_time
        }, status=status.HTTP_400_BAD_REQUEST)

    # --- Perform Face Verification ---
    temp_path = None
    face_verified = False
    try:
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_file:
            for chunk in face_image.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        if not user.face_reference_image:
             return Response({'error': 'Face reference data not found for user.'}, status=status.HTTP_400_BAD_REQUEST)

        face_verified = biometric_verifier.verify_face(
            temp_path,
            user.face_reference_image.path
        )
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)
    # --- End Face Verification ---


    if not face_verified:
        attempts_remaining = handle_failed_attempt(user) # Use helper
        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='failed', # More generic failure
            speaker_similarity_score=0,
            audio_deepfake_result=0,
            transcription_score=0,
            failure_reason='Face verification failed'
        )
        # Don't clear timer or step, allow retry within the time limit
        return Response({
            'error': 'Face verification failed',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time
        }, status=status.HTTP_401_UNAUTHORIZED)

    # Face verified successfully
    AuthenticationTimer.clear_timer(request, 'face')
    request.session['access_step'] = 2 # Update progress

    # Start voice timer
    voice_timeout = AuthenticationTimer.start_timer(request, 'voice')

    # Get challenge sentence for voice verification
    challenge_sentence = biometric_verifier.get_challenge_sentence()
    request.session['challenge_sentence'] = challenge_sentence

    return Response({
        'message': 'Face verified. Proceed with voice verification.',
        'challenge_sentence': challenge_sentence,
        'next_step': 'voice_verification',
        'remaining_time': voice_timeout
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@authentication_classes([SessionAuthentication])
def room_access_voice_verify(request):
    """Final step for room access: voice verification with timer"""
    room_id = request.session.get('access_room_id')
    challenge_sentence = request.session.get('challenge_sentence')
    current_step = request.session.get('access_step')

    if not room_id or not challenge_sentence or current_step != 2:
        return Response({
            'error': 'Invalid session state. Please start room access process again.'
        }, status=status.HTTP_400_BAD_REQUEST)

    user = request.user
    try:
        # Only allow accessing rooms in the user's company
        room = Room.objects.get(room_id=room_id, company=user.company)
    except Room.DoesNotExist:
         request.session.pop('access_room_id', None)
         request.session.pop('access_step', None)
         request.session.pop('challenge_sentence', None)
         AuthenticationTimer.clear_timer(request, 'voice')
         return Response({'error': 'Room not found'}, status=status.HTTP_404_NOT_FOUND)

    if user.is_frozen: # Re-check frozen status
        return Response({'error': 'Account is frozen'}, status=status.HTTP_403_FORBIDDEN)

    # Check timer
    is_valid, remaining_time = AuthenticationTimer.check_timer(request, 'voice')
    if not is_valid:
        attempts_remaining = handle_failed_attempt(user)
        request.session.pop('access_step', None) # Reset progress

        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='genuine', # Face was okay
            speaker_similarity_score=0,
            audio_deepfake_result=0,
            transcription_score=0,
            failure_reason='Voice verification timeout'
        )
        AuthenticationTimer.clear_timer(request, 'voice')
        return Response({
            'error': 'Voice verification timeout',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen
        }, status=status.HTTP_408_REQUEST_TIMEOUT)

    voice_recording = request.FILES.get('voice_recording')
    if not voice_recording:
        return Response({
            'error': 'Voice recording required',
            'remaining_time': remaining_time
        }, status=status.HTTP_400_BAD_REQUEST)

    # --- Perform Voice Verification ---
    temp_path = None
    voice_result = None
    try:
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            for chunk in voice_recording.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name

        if not user.voice_reference:
             return Response({'error': 'Voice reference data not found for user.'}, status=status.HTTP_400_BAD_REQUEST)

        voice_result = biometric_verifier.verify_voice(
            temp_path,
            user.voice_reference.path,
            challenge_sentence
        )
    finally:
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)
    # --- End Voice Verification ---

    if not voice_result:
        attempts_remaining = handle_failed_attempt(user)
        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='genuine',
            speaker_similarity_score=0,
            audio_deepfake_result=0,
            transcription_score=0,
            failure_reason='Voice verification processing failed' # Internal error
        )
        return Response({
            'error': 'Voice verification processing failed',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


    # Check verification thresholds
    threshold_passed = (
        voice_result['speaker_similarity'] >= 0.7 and
        voice_result['transcription_similarity'] >= 0.8 and
        voice_result['is_genuine_audio']
    )

    if not threshold_passed:
        attempts_remaining = handle_failed_attempt(user)
        failure_details = f"Speaker: {voice_result['speaker_similarity']:.2f}, Transcription: {voice_result['transcription_similarity']:.2f}, Genuine: {voice_result['is_genuine_audio']}"
        print(f"Room Access Voice verification failed for {user.username} in {room_id}: {failure_details}") # Log

        AccessLog.objects.create(
            user=user,
            room=room,
            company=user.company,
            access_granted=False,
            face_spoofing_result='genuine',
            speaker_similarity_score=voice_result['speaker_similarity'],
            audio_deepfake_result=1 if voice_result['is_genuine_audio'] else 0,
            transcription_score=voice_result['transcription_similarity'],
            failure_reason='Voice verification thresholds not met'
        )
        # Don't clear timer/step, allow retry
        return Response({
            'error': 'Voice verification failed',
            'attempts_remaining': attempts_remaining,
            'is_frozen': user.is_frozen,
            'remaining_time': remaining_time
        }, status=status.HTTP_401_UNAUTHORIZED)

    # --- Access Granted ---
    user.failed_attempts = 0 # Reset counter on success
    user.save()

    # Log successful access
    AccessLog.objects.create(
        user=user,
        room=room,
        company=user.company,
        access_granted=True,
        face_spoofing_result='genuine',
        speaker_similarity_score=voice_result['speaker_similarity'],
        audio_deepfake_result=1 if voice_result['is_genuine_audio'] else 0,
        transcription_score=voice_result['transcription_similarity']
    )
    
    room.is_unlocked = True
    room.unlock_timestamp = timezone.now()
    room.save()


    # Clear session data for this access attempt
    AuthenticationTimer.clear_timer(request, 'voice')
    request.session.pop('access_room_id', None)
    request.session.pop('challenge_sentence', None)
    request.session.pop('access_step', None)

    return Response({
        'message': 'Access granted',
        'room': {
            'id': room.id,
            'room_id': room.room_id,
            'name': room.name
        }
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated]) # Requires logged-in session
@authentication_classes([SessionAuthentication])
def get_user_profile(request):
    """
    Returns the profile information for the currently logged-in user.
    """
    user = request.user
    serializer = UserSerializer(user)
    return Response(serializer.data)




@api_view(['GET'])
@permission_classes([AllowAny])  # Allow unauthenticated access for ESP32
def get_room_status(request, room_id):
    """
    Check if a room is currently unlocked.
    This endpoint is intended for ESP32 devices to poll every few seconds.
    """
    try:
        room = Room.objects.get(room_id=room_id)
        
        # Check if room is unlocked and if the unlock is still valid
        is_unlocked = room.is_unlocked
        
        if is_unlocked and room.unlock_timestamp:
            # Check if the unlock has expired (e.g., after 30 seconds)
            time_since_unlock = timezone.now() - room.unlock_timestamp
            if time_since_unlock.total_seconds() > 30:  # 30 second unlock duration
                # Lock the room again
                room.is_unlocked = False
                room.unlock_timestamp = None
                room.save()
                is_unlocked = False
        
        return Response({
            'room_id': room_id,
            'is_unlocked': is_unlocked,
            'unlock_timestamp': room.unlock_timestamp
        })
    except Room.DoesNotExist:
        return Response({
            'error': 'Room not found'
        }, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_room_lock(request, room_id):
    """
    Toggle the lock/unlock status of a room.
    This endpoint is for admin use to manually control door locks.
    """
    try:
        # Find the room by room_id and ensure it's in the user's company
        room = Room.objects.get(room_id=room_id, company=request.user.company)
        
        # Only admins can toggle locks manually
        if not request.user.is_admin:
            return Response({
                'error': 'Admin privileges required to manually control locks'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the action (lock or unlock)
        action = request.data.get('action', 'toggle')
        
        # Update the lock status based on action
        if action == 'lock':
            room.is_unlocked = False
            room.unlock_timestamp = None
            operation = 'locked'
        elif action == 'unlock':
            room.is_unlocked = True
            room.unlock_timestamp = timezone.now()
            operation = 'unlocked'
        else:  # toggle
            room.is_unlocked = not room.is_unlocked
            if room.is_unlocked:
                room.unlock_timestamp = timezone.now()
                operation = 'unlocked'
            else:
                room.unlock_timestamp = None
                operation = 'locked'
        
        room.save()
        
        # Log this manual action
        AccessLog.objects.create(
            user=request.user,
            room=room,
            company=request.user.company,
            access_granted=True,
            face_spoofing_result='manual_operation',
            speaker_similarity_score=1.0,  # Placeholder values for manual operations
            audio_deepfake_result=1,
            transcription_score=1.0,
            failure_reason=None
        )
        
        return Response({
            'message': f'Room {room.name} has been {operation}',
            'room_id': room.room_id,
            'is_unlocked': room.is_unlocked,
            'unlock_timestamp': room.unlock_timestamp
        })
        
    except Room.DoesNotExist:
        return Response({
            'error': 'Room not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({
            'error': f'Failed to toggle room lock: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
