from django.urls import path
from . import views

urlpatterns = [
    path('ptz/direction',    views.PTZDirectionView.as_view()),
    path('ptz/move',         views.PTZMoveView.as_view()),
    path('ptz/position',     views.PTZPositionView.as_view()),
    path('zoom/day',         views.DayZoomView.as_view()),
    path('zoom/digital',     views.DigitalZoomView.as_view()),
    path('zoom/level',       views.ZoomLevelView.as_view()),
    path('speed',            views.SpeedView.as_view()),
    path('image/brightness', views.BrightnessView.as_view()),
    path('image/contrast',   views.ContrastView.as_view()),
    path('image/thermal-mode', views.ThermalModeView.as_view()),
    path('control',          views.GenericControlView.as_view()),
    path('rangefinder/measure', views.RangefinderView.as_view()),
    path('telemetry',        views.TelemetryView.as_view()),
    path('status',           views.JetsonStatusView.as_view()),
]
