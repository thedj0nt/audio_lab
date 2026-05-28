from django.urls import path
from .views import ProjectListCreateAPIView, TrackStreamView

urlpatterns = [
    # Project operations
    path('projects/', ProjectListCreateAPIView.as_view(), name='project-list-create'),
    
    # Range streaming for stems
    path('tracks/<int:pk>/stream/', TrackStreamView.as_view(), name='track-stream'),
]
