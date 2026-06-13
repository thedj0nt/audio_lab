from rest_framework import serializers
from .models import Project, Track

class TrackSerializer(serializers.ModelSerializer):
    """
    Serializer for Track model to represent its attributes and absolute file URL.
    """
    # Using DRF default FileField serialization which builds absolute URIs if request context is provided.
    class Meta:
        model = Track
        fields = ['id', 'project', 'name', 'file']
        read_only_fields = ['project']


class ProjectSerializer(serializers.ModelSerializer):
    """
    Serializer for Project model, containing nested Track data.
    """
    tracks = TrackSerializer(many=True, read_only=True)

    class Meta:
        model = Project
        fields = ['id', 'title', 'created_at', 'status', 'duration', 'bpm', 'scale', 'stems', 'tracks']
        read_only_fields = ['created_at', 'status', 'duration', 'bpm', 'scale', 'stems']
