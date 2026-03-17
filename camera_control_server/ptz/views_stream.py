"""
Live Stream Views
Returns Shinobi HLS stream URLs so Electron can play them.
No FFmpeg needed — Shinobi already converts RTSP to HLS.
"""
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.conf import settings
import requests
import logging

logger = logging.getLogger('ptz')

SHINOBI_URL = getattr(settings, 'SHINOBI_URL', 'http://localhost:8080')
SHINOBI_API_KEY = getattr(settings, 'SHINOBI_API_KEY', 'ynKZEwCmeGDJE3Y28ySkPKrata2x3N')
SHINOBI_GROUP = getattr(settings, 'SHINOBI_GROUP', 'hs1234')


class StreamListView(APIView):
    """Get all available streams from Shinobi"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            resp = requests.get(
                f"{SHINOBI_URL}/{SHINOBI_API_KEY}/monitor/{SHINOBI_GROUP}",
                timeout=5
            )
            monitors = resp.json()
            streams = []
            for m in monitors:
                hls_streams = m.get('streams', [])
                if hls_streams:
                    streams.append({
                        'id': m['mid'],
                        'name': m.get('name', m['mid']),
                        'mode': m.get('mode', 'unknown'),
                        'status': m.get('status', 'unknown'),
                        'hls_url': f"{SHINOBI_URL}{hls_streams[0]}",
                        'snapshot_url': f"{SHINOBI_URL}/{SHINOBI_API_KEY}/jpeg/{SHINOBI_GROUP}/{m['mid']}/s.jpg",
                    })
            return Response({'streams': streams})
        except Exception as e:
            logger.error(f"Shinobi error: {e}")
            return Response({'error': str(e), 'streams': []})


class StreamDetailView(APIView):
    """Get stream URL for a specific monitor"""
    permission_classes = [IsAuthenticated]

    def get(self, request, monitor_id):
        hls_url = f"{SHINOBI_URL}/{SHINOBI_API_KEY}/hls/{SHINOBI_GROUP}/{monitor_id}/s.m3u8"
        snapshot_url = f"{SHINOBI_URL}/{SHINOBI_API_KEY}/jpeg/{SHINOBI_GROUP}/{monitor_id}/s.jpg"
        return Response({
            'monitor_id': monitor_id,
            'hls_url': hls_url,
            'snapshot_url': snapshot_url,
        })
