# Eagerly load Celery application on Django initialization
from .celery import app as celery_app

__all__ = ('celery_app',)
