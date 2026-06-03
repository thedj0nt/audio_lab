import os
from celery import Celery

# Set default settings module for Celery worker
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')

app = Celery('core')

# Read celery variables namespace in settings.py with 'CELERY_' prefix
app.config_from_object('django.conf:settings', namespace='CELERY')

# Discover tasks automatically in tasks.py across all active apps
app.autodiscover_tasks()

@app.task(bind=True, ignore_result=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
