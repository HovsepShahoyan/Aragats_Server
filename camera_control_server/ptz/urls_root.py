from django.urls import path
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.conf import settings

@api_view(['GET'])
@permission_classes([AllowAny])
def root(request):
    return Response({
        'status': 'Aragats Camera Control Server Running',
        'jetson_url': settings.JETSON_URL,
        'port': 8766,
    })

@api_view(['GET'])
@permission_classes([AllowAny])
def health(request):
    return Response({'status': 'ok'})

urlpatterns = [
    path('', root),
    path('health', health),
]
