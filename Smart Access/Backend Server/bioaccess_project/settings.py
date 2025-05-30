"""
Django settings for bioaccess_project project.

Generated by 'django-admin startproject' using Django 5.1.6.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/5.1/ref/settings/
"""
import os
from datetime import timedelta
from pathlib import Path

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.1/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = 'django-insecure-7tnv6921we_a(v7t#rv+d&w$nf*vnoh=mu+z3+v-d2gg=4($ua'

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# Adjust this based on your Flutter development server port
# For production, list your actual domain(s)
ALLOWED_HOSTS = ['*']  # Keep as is for now during development if needed, but restrict in production

# ---- CORS Configuration ----
# For development: a more permissive approach to handle dynamic ports
CORS_ALLOW_ALL_ORIGINS = True  # Only use during development, never in production

# When you're ready for production, switch to this instead:
# CORS_ALLOW_ALL_ORIGINS = False
# CORS_ALLOWED_ORIGINS = [
#     "https://yourproductionsite.com",
# ]

# Still important to keep credentials allowed
CORS_ALLOW_CREDENTIALS = True

# Expose cookie headers to JavaScript
CORS_EXPOSE_HEADERS = [
    'Set-Cookie',
    'Cookie',
    'X-CSRFToken',
]

# Additional headers configuration
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'content-disposition',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
    'x-username',
    'x-session-token',
    'cookie',
]

CORS_ALLOW_METHODS = [
    'DELETE',
    'GET',
    'OPTIONS',
    'PATCH',
    'POST',
    'PUT',
]

# Similarly update CSRF trusted origins for development
CSRF_TRUSTED_ORIGINS = [
    # While in development, trust localhost regardless of port
    "http://localhost:5050",
    "http://localhost:*",  # Wildcard for any port on localhost
    "http://127.0.0.1:*",  # Wildcard for any port on 127.0.0.1
]

# ---- Session Configuration ----
# Session Settings
SESSION_COOKIE_SECURE = False  # Set to True in production with HTTPS
CSRF_COOKIE_SECURE = False  # Set to True in production with HTTPS
SESSION_COOKIE_SAMESITE = 'Lax'  # Critical for CORS in development
CSRF_COOKIE_SAMESITE = 'Lax'  # Critical for CORS in development

# Set cookie HTTPOnly settings correctly
SESSION_COOKIE_HTTPONLY = False  # Should be True for security
CSRF_COOKIE_HTTPONLY = False  # Must be False to allow JavaScript access to the token

# Explicitly set cookie domains
SESSION_COOKIE_DOMAIN = None
CSRF_COOKIE_DOMAIN = None

# Set session serializer
SESSION_SERIALIZER = 'django.contrib.sessions.serializers.JSONSerializer'

# Use database session backend (more reliable for cross-domain)
SESSION_ENGINE = 'django.contrib.sessions.backends.db'

# If SameSite is 'None', you must set Secure=True in production
# but for local development, we can use Secure=False
if not DEBUG:
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True

# Set session expiration (24 hours)
SESSION_COOKIE_AGE = 86400  # 24 hours in seconds
SESSION_EXPIRE_AT_BROWSER_CLOSE = False  # Keep session across browser restarts

# Make sure Django always sends cookies even for failed responses (important for auth)
SESSION_SAVE_EVERY_REQUEST = True

ENCRYPT_BIOMETRIC_DATA = True  # Set to False to disable encryption during development
KEY_DIRECTORY = os.path.join(BASE_DIR, 'keys')
os.makedirs(KEY_DIRECTORY, exist_ok=True)

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',  # Ensure sessions is enabled
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'core',
]

# ---- Fixed Middleware Order ----
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # CORS must be first
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'bioaccess_project.urls'  # Assuming your project root urls.py is here

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'bioaccess_project.wsgi.application'  # Assuming this is correct


# Database
# https://docs.djangoproject.com/en/5.1/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}


# Password validation
# https://docs.djangoproject.com/en/5.1/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# Internationalization
# https://docs.djangoproject.com/en/5.1/topics/i18n/

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
BIOMETRIC_ROOT = os.path.join(MEDIA_ROOT, 'biometric_data')


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.1/howto/static-files/

STATIC_URL = 'static/'
# STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')  # Define if you collect static files

# Default primary key field type
# https://docs.djangoproject.com/en/5.1/ref/settings/#default-auto-field

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

DATA_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10MB

AUTH_USER_MODEL = 'core.User'

# Django REST Framework Settings
REST_FRAMEWORK = {
    # Use SessionAuthentication as the primary method
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.SessionAuthentication',
    ),
    # Keep default renderers and parsers
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
        'rest_framework.renderers.BrowsableAPIRenderer',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
        'rest_framework.parsers.FormParser',
        'rest_framework.parsers.MultiPartParser',
    ],
    # Use IsAuthenticatedOrReadOnly or IsAuthenticated by default if desired
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ]
}

# ---- Enhanced Debug Logging ----
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'file': {
            'class': 'logging.FileHandler',
            'filename': os.path.join(BASE_DIR, 'django_debug.log'),
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': True,
        },
        'django.request': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'django.server': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'django.contrib.sessions': {
            'handlers': ['console', 'file'],
            'level': 'DEBUG',
            'propagate': False,
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
}
