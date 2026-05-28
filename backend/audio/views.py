import os
import re
from django.http import StreamingHttpResponse, Http404
from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from .models import Project, Track
from .serializers import ProjectSerializer, TrackSerializer

class ProjectListCreateAPIView(APIView):
    """
    API endpoint to list all audio projects and create a new one with multiple stems.
    """
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        """
        Lists all projects and their stems.
        """
        projects = Project.objects.all()
        serializer = ProjectSerializer(projects, many=True, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        """
        Creates a project and uploads one or more stems concurrently.
        Accepts: multipart/form-data
        Fields:
          - title: name of the project
          - files: list of audio files/stems (under the 'files' array key, 
                   or dynamically under individual keys)
        """
        title = request.data.get('title')
        if not title:
            return Response(
                {'error': 'Project title is required.'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Collect files from multipart form
        # Handles standard array parameters e.g., files[] or files
        files = request.FILES.getlist('files')
        
        # If files list is empty, fallback to taking all uploaded files in the request
        if not files:
            files = list(request.FILES.values())

        if not files:
            return Response(
                {'error': 'At least one audio stem file is required.'}, 
                status=status.HTTP_400_BAD_REQUEST
            )

        # Create the parent Project object
        project = Project.objects.create(title=title)

        # Build individual tracks for each stem
        try:
            for f in files:
                # Clean up track name from the filename
                filename = f.name
                if '.' in filename:
                    # Strip extension
                    name = '.'.join(filename.split('.')[:-1])
                else:
                    name = filename
                
                # Beautify track name (replace separators with spaces, capitalize)
                name = name.replace('_', ' ').replace('-', ' ').title()

                # Save the Track associated with this project
                Track.objects.create(
                    project=project,
                    name=name,
                    file=f
                )
        except Exception as e:
            # Cleanup created project if file processing fails
            project.delete()
            return Response(
                {'error': f'Failed to process file uploads: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Re-fetch project to ensure absolute file paths are generated in response
        serializer = ProjectSerializer(project, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class TrackStreamView(APIView):
    """
    API endpoint that serves audio files using HTTP 206 Partial Content range requests.
    Supports low-latency streaming, pause/resume, and seek operations on mobile devices.
    """
    authentication_classes = []
    permission_classes = []

    def get(self, request, pk):
        track = get_object_or_404(Track, pk=pk)
        
        # Validate that the file actually exists on disk
        if not track.file or not os.path.exists(track.file.path):
            raise Http404("Audio file could not be found on server disk.")

        file_path = track.file.path
        file_size = os.path.getsize(file_path)

        # Parse request Content-Range headers
        range_header = request.META.get('HTTP_RANGE', '').strip()
        range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)

        # Detect suitable audio content type for headers
        content_type = 'audio/mpeg'
        if file_path.endswith('.wav'):
            content_type = 'audio/wav'
        elif file_path.endswith('.ogg'):
            content_type = 'audio/ogg'
        elif file_path.endswith('.m4a'):
            content_type = 'audio/mp4'

        # Memory-efficient chunked generator for large files
        def file_chunk_generator(path, offset, length, chunk_size=16384):
            with open(path, 'rb') as f:
                f.seek(offset)
                bytes_remaining = length
                while bytes_remaining > 0:
                    to_read = min(chunk_size, bytes_remaining)
                    chunk = f.read(to_read)
                    if not chunk:
                        break
                    bytes_remaining -= len(chunk)
                    yield chunk

        if range_match:
            first_byte = int(range_match.group(1))
            last_byte_str = range_match.group(2)
            last_byte = int(last_byte_str) if last_byte_str else file_size - 1

            # Clamp boundaries
            if first_byte >= file_size:
                return Response(
                    {'error': 'Requested range not satisfiable'},
                    status=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE
                )
            
            last_byte = min(last_byte, file_size - 1)
            content_length = last_byte - first_byte + 1

            response = StreamingHttpResponse(
                file_chunk_generator(file_path, first_byte, content_length),
                status=status.HTTP_206_PARTIAL_CONTENT,
                content_type=content_type
            )
            response['Content-Range'] = f'bytes {first_byte}-{last_byte}/{file_size}'
            response['Accept-Ranges'] = 'bytes'
            response['Content-Length'] = str(content_length)
            return response
        else:
            # Fallback standard full file transfer
            response = StreamingHttpResponse(
                file_chunk_generator(file_path, 0, file_size),
                status=status.HTTP_200_OK,
                content_type=content_type
            )
            response['Accept-Ranges'] = 'bytes'
            response['Content-Length'] = str(file_size)
            return response
