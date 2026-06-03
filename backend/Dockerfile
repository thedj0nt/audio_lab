FROM python:3.10-slim

# Prevent Python from writing .pyc files to disk
ENV PYTHONDONTWRITEBYTECODE 1

# Prevent Python from buffering stdout and stderr
ENV PYTHONUNBUFFERED 1

# Set active working directory
WORKDIR /app

# Install system dependencies needed for compiling packages and decoding audio
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy and install python package dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy remaining code files into build directory
COPY . /app/

# Expose DRF application default port
EXPOSE 8000
