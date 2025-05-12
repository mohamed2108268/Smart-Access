import os
import tempfile
from django.utils import timezone
from datetime import timedelta
from cryptography.fernet import Fernet
from django.conf import settings
from deepface import DeepFace
import speech_recognition as sr
from pydub import AudioSegment
from resemblyzer import VoiceEncoder, preprocess_wav
from scipy.spatial.distance import cosine
import requests
from transformers import AutoFeatureExtractor, AutoModelForAudioClassification
import torch
import torchaudio
import base64
from django.conf import settings
import librosa
import nemo.collections.asr as nemo_asr


# The AuthenticationTimer class manages time limits for authentication steps. It provides methods to start timers,
# check if time limits have been exceeded, and clear timers when authentication is complete or failed. This helps
# ensure that authentication attempts must be completed within a reasonable time window for security.
class AuthenticationTimer:
    FACE_TIMEOUT = 20  # seconds
    VOICE_TIMEOUT = 30  # seconds

    @staticmethod
    def start_timer(request, step):
        """Start timer for authentication step"""
        start_time = timezone.now()
        if step == 'face':
            request.session['face_auth_start'] = start_time.isoformat()
            return AuthenticationTimer.FACE_TIMEOUT
        elif step == 'voice':
            request.session['voice_auth_start'] = start_time.isoformat()
            return AuthenticationTimer.VOICE_TIMEOUT
        return None

    @staticmethod
    def check_timer(request, step):
        """
        Check if authentication step is within time limit
        Returns (is_valid, remaining_time)
        """
        now = timezone.now()
        
        if step == 'face':
            start_str = request.session.get('face_auth_start')
            timeout = AuthenticationTimer.FACE_TIMEOUT
        elif step == 'voice':
            start_str = request.session.get('voice_auth_start')
            timeout = AuthenticationTimer.VOICE_TIMEOUT
        else:
            return False, 0

        if not start_str:
            return False, 0

        start_time = timezone.datetime.fromisoformat(start_str)
        elapsed = (now - start_time).total_seconds()
        remaining = max(0, timeout - elapsed)

        return elapsed <= timeout, remaining

    @staticmethod
    def clear_timer(request, step):
        """Clear timer from session"""
        if step == 'face':
            request.session.pop('face_auth_start', None)
        elif step == 'voice':
            request.session.pop('voice_auth_start', None)


# These variables and directories are set up at the module level to handle encryption keys. The system
# generates a new encryption key if one doesn't exist or loads the existing key from the key file.
# This key is used to encrypt all biometric data stored in the system.
KEY_DIR = os.path.join(settings.BASE_DIR, 'keys')
KEY_FILE = os.path.join(KEY_DIR, 'biometric.key')
os.makedirs(KEY_DIR, exist_ok=True)

# Generate or load key at module level
try:
    if os.path.exists(KEY_FILE):
        with open(KEY_FILE, 'rb') as key_file:
            ENCRYPTION_KEY = key_file.read()
    else:
        ENCRYPTION_KEY = Fernet.generate_key()
        with open(KEY_FILE, 'wb') as key_file:
            key_file.write(ENCRYPTION_KEY)
except Exception as e:
    print(f"Error handling encryption key: {e}")
    raise

# Create cipher suite at module level
CIPHER_SUITE = Fernet(ENCRYPTION_KEY)


# BiometricEncryption class provides methods to encrypt and decrypt biometric data files. This ensures that
# sensitive biometric templates are never stored in plaintext on the server, protecting user privacy and
# enhancing system security against unauthorized access to the stored biometric data.
class BiometricEncryption:
    def encrypt_file(self, file_path):
        try:
            with open(file_path, 'rb') as file:
                file_data = file.read()
            # Check if the file is already encrypted
            if file_data.startswith(b"gAAAAAB"):
                # Already encrypted, skip encryption
                return True
            encrypted_data = CIPHER_SUITE.encrypt(file_data)
            with open(file_path, 'wb') as file:
                file.write(encrypted_data)
            return True
        except Exception as e:
            print(f"Encryption error: {e}")
            return False

    def decrypt_file(self, file_path):
        try:
            with open(file_path, 'rb') as file:
                encrypted_data = file.read()
            decrypted_data = CIPHER_SUITE.decrypt(encrypted_data)
            # Preserve the original file extension
            _, ext = os.path.splitext(file_path)
            with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as temp_file:
                temp_file.write(decrypted_data)
            return temp_file.name
        except Exception as e:
            print(f"Decryption error: {e}")
            return None


# BiometricVerification class handles all biometric verification processes including face verification,
# voice verification, and deepfake detection. It loads AI models for these tasks and provides methods
# to compare live biometric samples against stored references, checking for matches and potential spoofing attempts.
class BiometricVerification:
    def __init__(self):
        self.encryption = BiometricEncryption()
        self.voice_encoder = VoiceEncoder()
        self.local_deepfake_model_path = os.path.join(settings.BASE_DIR, 'models', 'deepfake_audio_detection')
        # Check if the local model directory exists
        if not os.path.isdir(self.local_deepfake_model_path):
            # Option 1: Raise an error if the model MUST be local
            raise FileNotFoundError(
                f"Deepfake model directory not found at: {self.local_deepfake_model_path}. "
                f"Please run the download script (e.g., python download_models.py) first."
            )
            
        try:
            print(f"Loading deepfake model from: {self.local_deepfake_model_path}")
            # Load feature extractor and model from the specified local directory
            self.deepfake_feature_extractor = AutoFeatureExtractor.from_pretrained(self.local_deepfake_model_path)
            self.deepfake_model = AutoModelForAudioClassification.from_pretrained(self.local_deepfake_model_path)
            print("Deepfake model loaded successfully.")
        except Exception as e:
            print(f"CRITICAL ERROR: Failed to load deepfake model from {self.local_deepfake_model_path}: {e}")
            # Decide how to handle this - raise error, disable feature, etc.
            raise RuntimeError(f"Could not load the deepfake detection model: {e}")
        self.speaker_model = nemo_asr.models.EncDecSpeakerLabelModel.from_pretrained("nvidia/speakerverification_en_titanet_large")
        
    def verify_face(self, face_image_path, reference_image_path):
        """Verify face using DeepFace"""
        try:
            decrypted_reference = self.encryption.decrypt_file(reference_image_path)
            result = DeepFace.verify(
                img1_path=face_image_path,
                img2_path=decrypted_reference,
                model_name="VGG-Face",
                enforce_detection=False
            )
            os.unlink(decrypted_reference)
            return result.get('verified', False)
        except Exception as e:
            print(f"Face verification error: {e}")
            return False

    def process_audio(self, audio_file):
        """Convert audio to WAV format"""
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_wav:
            audio = AudioSegment.from_file(audio_file)
            audio = audio.set_frame_rate(16000)
            audio = audio.set_channels(1)
            audio.export(temp_wav.name, format='wav')
            return temp_wav.name

    def verify_voice(self, audio_path, reference_path, expected_text):
        """Verify voice using multiple checks"""
        try:
            # Process audio files
            wav_path = self.process_audio(audio_path)
            decrypted_reference = self.encryption.decrypt_file(reference_path)
            reference_wav = self.process_audio(decrypted_reference)

            # Transcribe audio
            recognizer = sr.Recognizer()
            with sr.AudioFile(wav_path) as source:
                audio_data = recognizer.record(source)
            transcription = recognizer.recognize_google(audio_data)
            
            # Calculate transcription similarity
            from difflib import SequenceMatcher
            similarity = SequenceMatcher(None, transcription.lower(), expected_text.lower()).ratio()
            
            # Verify speaker
            embedding_current = self._get_nemo_embedding(wav_path)
            embedding_reference = self._get_nemo_embedding(reference_wav)

            from scipy.spatial.distance import cosine
            speaker_similarity = 1 - cosine(embedding_current, embedding_reference)
            
            
            # Check for deepfake
            waveform, sample_rate = torchaudio.load(wav_path)
            if sample_rate != 16000:
                resampler = torchaudio.transforms.Resample(orig_freq=sample_rate, new_freq=16000)
                waveform = resampler(waveform)
            
            inputs = self.deepfake_feature_extractor(waveform.squeeze(), sampling_rate=16000, return_tensors="pt")
            outputs = self.deepfake_model(**inputs)
            deepfake_result = outputs.logits.argmax(dim=-1).item()

            # Cleanup
            os.unlink(wav_path)
            os.unlink(reference_wav)
            os.unlink(decrypted_reference)

            return {
                'transcription_similarity': similarity,
                'speaker_similarity': speaker_similarity,
                'is_genuine_audio': deepfake_result == 1,
                'transcription': transcription
            }
        except Exception as e:
            print(f"Voice verification error: {e}")
            return None
            
    def _get_nemo_embedding(self, wav_file_path):
        """
        Gets the speaker embedding from NeMo's TitaNet using a WAV file path.
        Returns a 1D NumPy array.
        """
        # embed_audio_file() can take a file path
        # it returns a torch tensor of shape (batch_size, embedding_dim)
        embedding_tensor = self.speaker_model.get_embedding(wav_file_path)
        # Usually the shape is (1, 192) for TitaNet. Squeeze out batch dimension:
        embedding_np = embedding_tensor[0].detach().cpu().numpy()
        return embedding_np
        
    def get_challenge_sentence(self):
        """Fetch random sentence from Quotable API"""
        try:
            api_url = "https://api.quotable.io/random?minLength=89&maxLength=101"
         # Make the request (still includes verify=False, consider security implications)
            response = requests.get(api_url, verify=False)
            
            response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)
            
            data = response.json()
            sentence = data.get('content')
            
            if response.status_code == 200:
                return response.json().get('content')
        except Exception as e:
            print(f"Error fetching challenge sentence: {e}")
        return "It took him a while to realize that everything he decided not to change, he was actually choosing."
        
        
# This function locks any rooms whose unlock status has expired. It's designed to be called periodically
# by a management command or scheduled task to ensure that doors don't remain unlocked indefinitely if
# the unlock timeout passes.
def lock_expired_rooms():
    """
    Utility function to lock any rooms whose unlock has expired.
    This can be called by a management command or a scheduled task.
    """
    now = timezone.now()
    # Get all unlocked rooms
    unlocked_rooms = Room.objects.filter(is_unlocked=True).exclude(unlock_timestamp=None)

    # Check each room's unlock time
    for room in unlocked_rooms:
        time_since_unlock = now - room.unlock_timestamp
    # If unlocked more than 30 seconds ago, lock it
    if time_since_unlock.total_seconds() > 30:
        room.is_unlocked = False
        room.unlock_timestamp = None
        room.save()
        print(f"Locked room {room.room_id} due to timeout")
