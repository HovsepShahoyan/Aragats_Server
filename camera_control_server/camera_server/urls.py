from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('ptz.urls_auth')),
    path('api/jetson/', include('ptz.urls')),
    path('api/stream/', include('ptz.urls_stream')),
    path('', include('ptz.urls_root')),
]
