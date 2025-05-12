from django.core.management.base import BaseCommand
from core.utils import lock_expired_rooms

class Command(BaseCommand):
    help = 'Lock any rooms whose unlock has expired'

    def handle(self, *args, **options):
        lock_expired_rooms()
        self.stdout.write(self.style.SUCCESS('Successfully checked and locked expired rooms'))
