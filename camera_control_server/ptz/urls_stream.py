from django.urls import path
from . import views_stream

urlpatterns = [
    path('list/', views_stream.StreamListView.as_view()),
    path('<str:monitor_id>/', views_stream.StreamDetailView.as_view()),
]
