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
