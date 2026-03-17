#!/bin/bash
# ============================================================
#  Switch to JWT Authentication
# ============================================================
#
#  Run on Ubuntu PC:
#    bash switch_to_jwt.sh
#
#  Changes:
#    - Token auth → JWT auth
#    - Login returns access + refresh tokens
#    - Access token expires in 1 hour
#    - Refresh token expires in 7 days
#    - Header changes: "Authorization: Bearer <token>"
#
# ============================================================

set -e

PROJECT_DIR="$HOME/camera_control_server"
cd "$PROJECT_DIR"

echo ""
echo "🔐 Switching to JWT authentication..."
echo ""

# ==================== 1. Install JWT package ====================
echo "📦 Installing djangorestframework-simplejwt..."
pip install djangorestframework-simplejwt --break-system-packages 2>/dev/null || \
pip install djangorestframework-simplejwt

# ==================== 2. Update settings.py ====================
cat > camera_server/settings.py << 'SETTINGS_EOF'
import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'aragats-camera-server-change-in-production')
DEBUG = True
ALLOWED_HOSTS = ['*']
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'rest_framework',
    'ptz',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

ROOT_URLCONF = 'camera_server.urls'

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

WSGI_APPLICATION = 'camera_server.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

# JWT settings
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Yerevan'
USE_TZ = True
STATIC_URL = 'static/'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

JETSON_URL = os.environ.get('JETSON_URL', 'http://192.168.0.104:8000')
JETSON_TIMEOUT = 5
SETTINGS_EOF

echo "   ✅ Updated settings.py with JWT"

# ==================== 3. Update auth endpoints ====================
cat > ptz/urls_auth.py << 'EOF'
"""
JWT Authentication endpoints:
  POST /api/auth/login/       — get access + refresh tokens
  POST /api/auth/refresh/     — get new access token using refresh token
  GET  /api/auth/check/       — check if token is valid, get role
  POST /api/auth/users/create/ — create user (admin only)
  GET  /api/auth/users/        — list users (admin only)
  POST /api/auth/users/delete/ — delete user (admin only)
"""
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.urls import path
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken


def get_role(user):
    return 'admin' if user.is_staff else 'user'


def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    # Add custom claims
    refresh['username'] = user.username
    refresh['role'] = get_role(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """
    Send: {"username": "admin", "password": "admin123"}
    Get:  {"access": "eyJ...", "refresh": "eyJ...", "username": "admin", "role": "admin"}

    Use access token: Authorization: Bearer eyJ...
    When access expires, use refresh token to get a new one.
    """
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({'error': 'username and password required'}, status=400)

    user = authenticate(username=username, password=password)
    if user is None:
        return Response({'error': 'wrong username or password'}, status=401)

    tokens = get_tokens_for_user(user)
    return Response({
        'access': tokens['access'],
        'refresh': tokens['refresh'],
        'username': user.username,
        'role': get_role(user),
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def refresh_token(request):
    """
    Send: {"refresh": "eyJ..."}
    Get:  {"access": "eyJ...", "refresh": "eyJ..."}

    Use this when access token expires (1 hour).
    Refresh token lasts 7 days.
    """
    refresh = request.data.get('refresh')
    if not refresh:
        return Response({'error': 'refresh token required'}, status=400)

    try:
        token = RefreshToken(refresh)
        return Response({
            'access': str(token.access_token),
            'refresh': str(token),
        })
    except Exception:
        return Response({'error': 'invalid or expired refresh token'}, status=401)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check(request):
    return Response({
        'authenticated': True,
        'username': request.user.username,
        'role': get_role(request.user),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_user(request):
    if not request.user.is_staff:
        return Response({'error': 'admin only'}, status=403)

    username = request.data.get('username')
    password = request.data.get('password')
    role = request.data.get('role', 'user')

    if not username or not password:
        return Response({'error': 'username and password required'}, status=400)

    if User.objects.filter(username=username).exists():
        return Response({'error': 'username already exists'}, status=400)

    user = User.objects.create_user(username=username, password=password)
    if role == 'admin':
        user.is_staff = True
        user.save()

    return Response({'username': user.username, 'role': get_role(user), 'status': 'created'})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_users(request):
    if not request.user.is_staff:
        return Response({'error': 'admin only'}, status=403)

    return Response([
        {'id': u.id, 'username': u.username, 'role': get_role(u)}
        for u in User.objects.all()
    ])


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_user(request):
    if not request.user.is_staff:
        return Response({'error': 'admin only'}, status=403)

    username = request.data.get('username')
    if not username:
        return Response({'error': 'username required'}, status=400)
    if username == request.user.username:
        return Response({'error': 'cannot delete yourself'}, status=400)

    try:
        user = User.objects.get(username=username)
        user.delete()
        return Response({'status': 'deleted', 'username': username})
    except User.DoesNotExist:
        return Response({'error': 'user not found'}, status=404)


urlpatterns = [
    path('login/', login),
    path('refresh/', refresh_token),
    path('check/', check),
    path('users/', list_users),
    path('users/create/', create_user),
    path('users/delete/', delete_user),
]
EOF

echo "   ✅ Updated auth endpoints for JWT"

# ==================== 4. Update urls.py ====================
cat > camera_server/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('ptz.urls_auth')),
    path('api/jetson/', include('ptz.urls')),
    path('', include('ptz.urls_root')),
]
EOF

echo "   ✅ Updated URLs"

# ==================== 5. Migrate ====================
python3 manage.py migrate --verbosity 0
echo "   ✅ Database updated"

echo ""
echo "============================================================"
echo "  ✅ JWT AUTH READY"
echo "============================================================"
echo ""
echo "  Restart server: bash start.sh"
echo ""
echo "  LOGIN:"
echo "    curl -s -X POST http://localhost:8766/api/auth/login/ \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"username\": \"admin\", \"password\": \"admin123\"}'"
echo ""
echo "  RETURNS:"
echo "    {\"access\": \"eyJ...\", \"refresh\": \"eyJ...\", \"role\": \"admin\"}"
echo ""
echo "  USE TOKEN (note: Bearer, not Token):"
echo "    curl http://localhost:8766/api/jetson/status \\"
echo "      -H 'Authorization: Bearer ACCESS_TOKEN_HERE'"
echo ""
echo "  REFRESH (when access expires after 1 hour):"
echo "    curl -X POST http://localhost:8766/api/auth/refresh/ \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"refresh\": \"REFRESH_TOKEN_HERE\"}'"
echo ""
echo "  Access token:  expires in 1 hour"
echo "  Refresh token: expires in 7 days"
echo "============================================================"
