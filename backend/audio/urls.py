from django.urls import path
from .views import ProjectListCreateAPIView, ProjectDetailAPIView, TrackStreamView

urlpatterns = [
    # Project operations
    path('projects/', ProjectListCreateAPIView.as_view(), name='project-list-create'),
    path('projects/<int:pk>/', ProjectDetailAPIView.as_view(), name='project-detail'),
    
    # Range streaming for stems
    path('tracks/<int:pk>/stream/', TrackStreamView.as_view(), name='track-stream'),
]
