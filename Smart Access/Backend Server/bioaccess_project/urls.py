# bioaccess/urls.py
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('core.urls')),  # All our API endpoints
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)  # For serving media files in development
