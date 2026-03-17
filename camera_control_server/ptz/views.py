"""
PTZ API Views - Proxies commands to Jetson at 192.168.0.104:8000
All endpoints require login except /status
"""
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from .jetson_client import jetson
from .serializers import (
    PTZDirectionSerializer, PTZMoveSerializer,
    ZoomDirectionSerializer, ZoomLevelSerializer,
    SpeedSerializer, AdjustSerializer,
    ThermalModeSerializer, ControlSerializer,
)

DAY_ZOOM_VALUES = [1, 5, 15, 30, 60, 68]


class PTZDirectionView(APIView):
    def post(self, request):
        ser = PTZDirectionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/set_ptz_direction', ser.validated_data))


class PTZMoveView(APIView):
    def post(self, request):
        ser = PTZMoveSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/move_ptz', ser.validated_data))


class DayZoomView(APIView):
    def post(self, request):
        ser = ZoomDirectionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        current = jetson.get('/api/system/current_zoom')
        current_level = current.get('zoom', 1)
        try:
            idx = DAY_ZOOM_VALUES.index(current_level)
        except ValueError:
            idx = 0
        if ser.validated_data['direction'] == 'in':
            idx = min(idx + 1, len(DAY_ZOOM_VALUES) - 1)
        else:
            idx = max(idx - 1, 0)
        result = jetson.post('/api/system/set_zoom', {'level': DAY_ZOOM_VALUES[idx]})
        result['zoom_level'] = DAY_ZOOM_VALUES[idx]
        return Response(result)


class DigitalZoomView(APIView):
    def post(self, request):
        ser = ZoomDirectionSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/set_zoom', {'level': 1}))


class ZoomLevelView(APIView):
    def post(self, request):
        ser = ZoomLevelSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/set_zoom', ser.validated_data))


class SpeedView(APIView):
    def post(self, request):
        ser = SpeedSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/set_speed', ser.validated_data))


class BrightnessView(APIView):
    def post(self, request):
        ser = AdjustSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        val = '80' if ser.validated_data['direction'] == 'up' else '20'
        return Response(jetson.post('/api/system/send_control', {
            'prop': 'image', 'key': 'brightness', 'value': val}))


class ContrastView(APIView):
    def post(self, request):
        ser = AdjustSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        val = '80' if ser.validated_data['direction'] == 'up' else '20'
        return Response(jetson.post('/api/system/send_control', {
            'prop': 'image', 'key': 'contrast', 'value': val}))


class ThermalModeView(APIView):
    def post(self, request):
        ser = ThermalModeSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/send_control', {
            'prop': 'thermal', 'key': 'mode', 'value': ser.validated_data['mode']}))


class GenericControlView(APIView):
    def post(self, request):
        ser = ControlSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        return Response(jetson.post('/api/system/send_control', ser.validated_data))


class RangefinderView(APIView):
    def post(self, request):
        return Response(jetson.post('/api/system/rangefinder/measure', {}))


class TelemetryView(APIView):
    def get(self, request):
        return Response(jetson.get('/api/system/telemetry'))


class PTZPositionView(APIView):
    def get(self, request):
        return Response(jetson.get('/api/system/ptz_position'))


class JetsonStatusView(APIView):
    permission_classes = [AllowAny]
    def get(self, request):
        return Response(jetson.is_online())
