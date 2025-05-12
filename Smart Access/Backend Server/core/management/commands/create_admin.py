    # core/management/commands/create_admin.py
from django.core.management.base import BaseCommand
from django.core.files import File
from core.models import User
import os

class Command(BaseCommand):
    help = 'Creates an admin user with all required fields'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, required=True)
        parser.add_argument('--email', type=str, required=True)
        parser.add_argument('--password', type=str, required=True)
        parser.add_argument('--full_name', type=str, required=True)
        parser.add_argument('--phone_number', type=str, required=True)
        parser.add_argument('--face_image', type=str, required=True, help='Path to face image file')
        parser.add_argument('--voice_file', type=str, required=True, help='Path to voice file')

    def handle(self, *args, **options):
        try:
            # Check if user exists
            if User.objects.filter(username=options['username']).exists():
                self.stdout.write(self.style.ERROR(f'User {options["username"]} already exists'))
                return

            # Create admin user
            user = User.objects.create_user(
                username=options['username'],
                email=options['email'],
                password=options['password'],
                full_name=options['full_name'],
                phone_number=options['phone_number'],
                is_staff=True,
                is_superuser=True,
                is_admin=True
            )

            # Add biometric data
            with open(options['face_image'], 'rb') as face_file:
                user.face_reference_image.save(
                    f"{user.username}_face.jpg",
                    File(face_file)
                )

            with open(options['voice_file'], 'rb') as voice_file:
                user.voice_reference.save(
                    f"{user.username}_voice.wav",
                    File(voice_file)
                )

            user.save()

            self.stdout.write(self.style.SUCCESS(f'Successfully created admin user: {options["username"]}'))

        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error creating admin user: {str(e)}'))
            if 'user' in locals():
                user.delete()
