# SmartAccess: Biometric Access Control System

This is my graduation project for the Computer Science program. It's a biometric access control system that uses facial recognition and voice verification to control access to rooms.

## Project Overview

SmartAccess is a Django-based web application that works with ESP32 microcontrollers connected to door locks. The system provides:

- User authentication using face and voice biometrics
- Multi-tenant support for different organizations
- Admin interface for managing users and access permissions
- Integration with door lock hardware through ESP32 devices
- Security features including biometric data encryption and account freezing

## System Components

- **Django Backend**: Handles authentication, access control, and API endpoints
- **ESP32 Hardware**: Controls the physical door locks
- **Flutter App** (not included in this repo): Provides user interface for authentication

## Features

- **Two-factor Biometric Authentication**: Face + voice verification
- **Anti-spoofing**: Detection of fake faces and deepfake audio
- **Challenge-Response**: Dynamic voice challenges for verification
- **Encrypted Storage**: All biometric data is encrypted at rest
- **Access Logging**: Detailed logs of all access attempts

## Project Structure

- `core/` - Main Django app with models and views
- `bioaccess_project/` - Django project settings
- `media/` - Storage for encrypted biometric data
- `keys/` - Storage for encryption keys

## Setup Instructions

1. Clone this repository
2. Install required packages: `pip install -r requirements.txt`
3. Run migrations: `python manage.py migrate`
4. Create a superuser: `python manage.py createsuperuser`
5. Start the server: `python manage.py runserver`

## ESP32 Integration

The ESP32 microcontrollers poll the server periodically to check if a room should be unlocked. When a user is authenticated, the server sets the room's status to unlocked, which the ESP32 detects on its next poll.

## Technologies Used

- Django and Django REST Framework
- DeepFace for facial recognition
- NeMo for speaker verification
- PyTorch for deepfake detection
- Cryptography.io for data encryption

## Future Improvements

- Add fingerprint authentication
- Implement push notifications for access events
- Develop admin mobile app
- Add support for temporary access passes

## Contact

Created by [Your Name] - feel free to contact me!
