from rest_framework import serializers

class PTZDirectionSerializer(serializers.Serializer):
    direction = serializers.CharField()
    start = serializers.BooleanField()

class PTZMoveSerializer(serializers.Serializer):
    azimuth = serializers.IntegerField()
    elevation = serializers.IntegerField()

class ZoomDirectionSerializer(serializers.Serializer):
    direction = serializers.ChoiceField(choices=['in', 'out'])

class ZoomLevelSerializer(serializers.Serializer):
    level = serializers.IntegerField(min_value=1, max_value=68)

class SpeedSerializer(serializers.Serializer):
    speed = serializers.IntegerField(min_value=1, max_value=8)

class AdjustSerializer(serializers.Serializer):
    direction = serializers.ChoiceField(choices=['up', 'down'])

class ThermalModeSerializer(serializers.Serializer):
    mode = serializers.CharField()

class ControlSerializer(serializers.Serializer):
    prop = serializers.CharField()
    key = serializers.CharField()
    value = serializers.CharField()
