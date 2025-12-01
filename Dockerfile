## Parent image
FROM python:3.10-slim

## Essential environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

## Work directory inside the docker container
WORKDIR /app

## Installing system dependancies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

## Copying ur all contents from local to app
COPY . .

## Copy pip configuration for better timeout handling
COPY pip.conf /etc/pip.conf

## Run setup.py with increased timeout and retries for large packages
RUN pip install --no-cache-dir --default-timeout=300 --retries=5 -e .

# Used PORTS
EXPOSE 8501
EXPOSE 9999

# Run the app 
CMD ["python", "app/main.py"]