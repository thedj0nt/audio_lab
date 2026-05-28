from django.db import models

class Project(models.Model):
    """
    Represents an audio project or song containing multiple multi-track stems.
    """
    title = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title


def track_upload_path(instance, filename):
    """
    Groups track audio stem uploads by project ID under the 'projects/' directory.
    """
    project_id = instance.project.id if instance.project.id else 'temp'
    return f'projects/{project_id}/{filename}'


class Track(models.Model):
    """
    Represents an individual audio stem/track within a project.
    """
    project = models.ForeignKey(
        Project, 
        related_name='tracks', 
        on_delete=models.CASCADE
    )
    name = models.CharField(max_length=255)
    file = models.FileField(upload_to=track_upload_path)

    def __str__(self):
        return f"{self.project.title} - {self.name}"
