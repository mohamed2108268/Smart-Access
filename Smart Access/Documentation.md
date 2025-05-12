# SmartAccess: Project Documentation

## System Architecture

SmartAccess uses a client-server architecture:

1. **Django Backend (This Project)**
   - REST API for client communication
   - Database for storing user data and access logs
   - Biometric processing and verification
   - Authentication and authorization

2. **Flutter Mobile App** (Not included in this repository)
   - User interface for authentication
   - Camera and microphone access for biometrics
   - Communication with the backend via REST API

3. **ESP32 Hardware** (Not included in this repository)
   - Physical door lock control
   - Communication with the backend to check access status

## Authentication Flow

The system uses a multi-step authentication process:

1. **User Registration**
   - User provides credentials and company info
   - User records face and voice samples
   - Backend encrypts and stores biometric data

2. **Login Process**
   - Step 1: Credential verification (username/password)
   - Step 2: Face verification (within a time limit)
   - Step 3: Voice verification with challenge phrase (within a time limit)

3. **Room Access**
   - User selects a room to access
   - Backend checks user permissions for the room
   - User completes biometric verification (face and voice)
   - Backend signals ESP32 to unlock the door temporarily

## Database Schema

The database includes these main tables:

- **User**: Extended from Django's AbstractUser with biometric data references
- **Company**: For multi-tenant support
- **Room**: Physical spaces with access control
- **RoomGroup**: Groups of rooms for easier permission management
- **UserRoomGroup**: Junction table for user-roomgroup permissions
- **AccessLog**: Records of all access attempts
- **InviteToken**: For secure user onboarding

## Security Features

1. **Biometric Data Security**
   - All biometric templates are encrypted at rest
   - Decryption occurs only during verification
   - Files are stored in secure locations

2. **Anti-Spoofing Measures**
   - Face spoofing detection
   - Voice deepfake detection
   - Challenge-response for voice verification

3. **Account Security**
   - Account freezing after 3 failed attempts
   - Time-limited verification windows
   - Comprehensive access logging

## API Endpoints

### Authentication Endpoints
- `/api/auth/csrf/`: Get CSRF token for session-based auth
- `/api/auth/register/`: Register new user with biometrics
- `/api/auth/verify-token/`: Verify invitation token
- `/api/auth/login/step1/`: Credential verification
- `/api/auth/login/step2/`: Face verification
- `/api/auth/login/step3/`: Voice verification
- `/api/auth/logout/`: End user session

### User Endpoints
- `/api/user/profile/`: Get current user profile
- `/api/user/rooms/`: List rooms accessible to current user

### Room Access Endpoints
- `/api/rooms/access/request/`: Initiate room access request
- `/api/rooms/access/face-verify/`: Face verification for room access
- `/api/rooms/access/voice-verify/`: Voice verification for room access
- `/api/rooms/<room_id>/status/`: Check room lock status
- `/api/rooms/<room_id>/toggle-lock/`: Admin control for room locks

### Admin Endpoints
- `/api/admin/access-logs/`: View access logs
- `/api/admin/frozen-accounts/`: View frozen accounts
- `/api/admin/unfreeze-account/`: Unfreeze account
- `/api/admin/user-permissions/`: Manage user permissions
- `/api/admin/users/`: List users
- `/api/admin/company/`: View company details
- `/api/admin/create-invite/`: Create invitation token

## Hardware Integration

The ESP32 microcontrollers communicate with the backend through a simple polling mechanism:

1. ESP32 periodically calls `/api/rooms/<room_id>/status/` (e.g., every 2 seconds)
2. When a user is authenticated, the backend sets `is_unlocked` to true with a timestamp
3. ESP32 detects the change and activates the door lock mechanism
4. After 30 seconds, or when manually locked, the door returns to locked state

## Setup Instructions

### Prerequisites
- Python 3.8 or higher
- Django 3.2 or higher
- PostgreSQL (recommended for production) or SQLite (for development)
- Required Python packages (see requirements.txt)

### Installation Steps
1. Clone the repository
2. Create a virtual environment: `python -m venv venv`
3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - Linux/Mac: `source venv/bin/activate`
4. Install dependencies: `pip install -r requirements.txt`
5. Configure database settings in `settings.py`
6. Run migrations: `python manage.py migrate`
7. Create admin user: `python manage.py createsuperuser`
8. Start the server: `python manage.py runserver`

### Creating Your First Company and User
1. Log in to the admin interface at `/admin/`
2. Create a new Company
3. Create a User assigned to that Company with admin privileges
4. Use the API to upload biometric data for that user

## Deployment Considerations

For production deployment, consider:
1. Using PostgreSQL instead of SQLite
2. Setting up Nginx as a reverse proxy
3. Using Gunicorn as the WSGI server
4. Setting up SSL certificates for HTTPS
5. Configuring proper backups for the database and biometric data

## Troubleshooting

Common issues:
- **Biometric verification fails**: Check lighting conditions for face verification and background noise for voice
- **ESP32 not connecting**: Ensure it has network connectivity and the correct API endpoint
- **Account frozen**: An admin must unfreeze the account through the admin interface

## Future Development

Possible improvements:
- Add fingerprint authentication
- Implement push notifications for access events
- Develop admin mobile app
- Add support for temporary access passes
