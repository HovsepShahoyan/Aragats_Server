#!/bin/bash
cd "$(dirname "$0")"
echo "Starting Aragats Camera Control Server on port 8766..."
echo "Jetson: $JETSON_URL"
echo "Admin panel: http://localhost:8766/admin/"
echo ""
python3 manage.py runserver 0.0.0.0:8766
