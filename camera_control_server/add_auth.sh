#!/bin/bash
# ============================================================
#  Add Auth + Roles to Camera Control Server
# ============================================================
#
#  Run on Ubuntu PC:
#    bash add_auth.sh
#
#  Both admin and user have full access to everything.
#  Login returns role so Electron app knows who's logged in.
#  Later we will restrict some features to admin only.
#
# ============================================================

set -e

PROJECT_DIR="$HOME/camera_control_server"
cd "$PROJECT_DIR"

echo ""
echo "🔐 Adding authentication + roles..."
echo ""

# ==================== 1. Add authtoken to INSTALLED_APPS ====================
if grep -q "rest_framework.authtoken" camera_server/settings.py; then
    echo "   Token app already in settings.py"
else
    sed -i "s/'rest_framework',/'rest_framework',\n    'rest_framework.authtoken',/" camera_server/settings.py
    echo "   ✅ Added rest_framework.authtoken to INSTALLED_APPS"
fi

# ==================== 2. Create auth endpoints ====================
cat > ptz/urls_auth.py << 'EOF'
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.urls import path
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token


def get_role(user):
    return 'admin' if user.is_staff else 'user'


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    username = request.data.get('username')
    password = request.data.get('password')

    if not username or not password:
        return Response({'error': 'username and password required'}, status=400)

    user = authenticate(username=username, password=password)
    if user is None:
        return Response({'error': 'wrong username or password'}, status=401)

    token, _ = Token.objects.get_or_create(user=user)
    return Response({
        'token': token.key,
        'username': user.username,
        'role': get_role(user),
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        request.user.auth_token.delete()
    except Exception:
        pass
    return Response({'status': 'logged out'})


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
    path('logout/', logout),
    path('check/', check),
    path('users/', list_users),
    path('users/create/', create_user),
    path('users/delete/', delete_user),
]
EOF

echo "   ✅ Created auth endpoints"

# ==================== 3. Update main urls.py ====================
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

# ==================== 4. Migrate ====================
python3 manage.py migrate --verbosity 0
echo "   ✅ Database updated"

# ==================== 5. Generate admin token ====================
TOKEN=$(python3 manage.py shell -c "
from rest_framework.authtoken.models import Token
from django.contrib.auth.models import User
token, _ = Token.objects.get_or_create(user=User.objects.get(username='admin'))
print(token.key)
")

echo ""
echo "============================================================"
echo "  ✅ AUTH READY"
echo "============================================================"
echo ""
echo "  Admin token: $TOKEN"
echo ""
echo "  Restart server: bash start.sh"
echo ""
echo "  Login:"
echo "    curl -X POST http://localhost:8766/api/auth/login/ \\"
echo "      -H 'Content-Type: application/json' \\"
echo "      -d '{\"username\": \"admin\", \"password\": \"admin123\"}'"
echo ""
echo "  Returns: {\"token\": \"...\", \"username\": \"admin\", \"role\": \"admin\"}"
echo ""
echo "  Use token:"
echo "    curl http://localhost:8766/api/jetson/telemetry \\"
echo "      -H 'Authorization: Token $TOKEN'"
echo ""
echo "  Create users (admin only):"
echo "    POST /api/auth/users/create/"
echo "    {\"username\": \"viewer1\", \"password\": \"pass123\"}"
echo ""
echo "  List users:  GET  /api/auth/users/"
echo "  Delete user: POST /api/auth/users/delete/"
echo "============================================================"
