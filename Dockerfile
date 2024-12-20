FROM python:3.9-slim

# Install system dependencies including ADB and OCR support
RUN apt-get update && apt-get install -y \
    procps \
    android-tools-adb \
    usbutils \
    curl \
    udev \
    git \
    tesseract-ocr \
    libtesseract-dev \
    supervisor \
    sudo \
    iptables \
    net-tools \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -f plugdev

# Configure network for ADB
RUN echo '#!/bin/bash' > /app/setup-network.sh && \
    echo 'iptables -A INPUT -p tcp --dport 5037 -j ACCEPT' >> /app/setup-network.sh && \
    echo 'iptables -A INPUT -p tcp --dport 42356 -j ACCEPT' >> /app/setup-network.sh && \
    echo 'iptables -A OUTPUT -p tcp --sport 5037 -j ACCEPT' >> /app/setup-network.sh && \
    echo 'iptables -A OUTPUT -p tcp --sport 42356 -j ACCEPT' >> /app/setup-network.sh && \
    chmod +x /app/setup-network.sh

# Set up sudo access
RUN echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set the working directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p /app/logs /app/data /app/accounts /app/api

# Copy source files and verify
COPY . /app/

# Set executable permissions for scripts
RUN chmod +x /app/start.sh

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN touch /var/log/supervisor/supervisord.log && \
    chmod -R 777 /var/log/supervisor /app/logs

# Create supervisor program configurations
# ADB server program
RUN echo '[program:adb]' > /etc/supervisor/conf.d/adb.conf && \
    echo 'command=adb -a -P 5037 start-server' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'startsecs=5' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'startretries=3' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'stopasgroup=true' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'killasgroup=true' >> /etc/supervisor/conf.d/adb.conf && \
    echo 'priority=10' >> /etc/supervisor/conf.d/adb.conf && \
    echo '' >> /etc/supervisor/conf.d/adb.conf

# ADB connection program
RUN echo '[program:adb_connect]' > /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'command=/app/start.sh' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'autorestart=unexpected' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'startsecs=5' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'startretries=3' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'stopasgroup=true' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'killasgroup=true' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'priority=20' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo 'depends_on=adb' >> /etc/supervisor/conf.d/adb_connect.conf && \
    echo '' >> /etc/supervisor/conf.d/adb_connect.conf

RUN echo '[program:api]' > /etc/supervisor/conf.d/api.conf && \
    echo 'command=python3 -m uvicorn api.main:app --host 0.0.0.0 --port 8000 --log-level debug' >> /etc/supervisor/conf.d/api.conf && \
    echo 'directory=/app' >> /etc/supervisor/conf.d/api.conf && \
    echo 'environment=PYTHONPATH=/app:/app/api,PYTHONUNBUFFERED=1' >> /etc/supervisor/conf.d/api.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/api.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/api.conf && \
    echo 'startsecs=5' >> /etc/supervisor/conf.d/api.conf && \
    echo 'startretries=3' >> /etc/supervisor/conf.d/api.conf && \
    echo 'stopasgroup=true' >> /etc/supervisor/conf.d/api.conf && \
    echo 'killasgroup=true' >> /etc/supervisor/conf.d/api.conf && \
    echo 'stdout_logfile=/app/logs/api.log' >> /etc/supervisor/conf.d/api.conf && \
    echo 'stderr_logfile=/app/logs/api.error.log' >> /etc/supervisor/conf.d/api.conf

# Copy and setup udev rules
COPY 51-android.rules /etc/udev/rules.d/
RUN chmod a+r /etc/udev/rules.d/51-android.rules \
    && chown root:root /etc/udev/rules.d/51-android.rules

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV HOME=/root
ENV TESSDATA_PREFIX=/usr/share/tesseract-ocr/4.00/tessdata
ENV PYTHONPATH=/app:/app/api

# Install system dependencies for psutil and cryptography
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    libffi-dev \
    libssl-dev

# Install Python dependencies
RUN pip install fastapi uvicorn gramaddict pytesseract colorama uiautomator2 psutil pyyaml && \
    pip install cryptography && \
    pip install PyJWT==2.8.0 python-jwt==4.1.0

# Create startup script for ADB connection
RUN echo '#!/bin/bash' > /app/connect-device.sh && \
    echo 'if [ ! -z "$ADB_DEVICE_IP" ] && [ ! -z "$ADB_DEVICE_PORT" ]; then' >> /app/connect-device.sh && \
    echo '    echo "Connecting to device at $ADB_DEVICE_IP:$ADB_DEVICE_PORT"' >> /app/connect-device.sh && \
    echo '    for i in {1..5}; do' >> /app/connect-device.sh && \
    echo '        echo "Attempt $i/5: Connecting to device..."' >> /app/connect-device.sh && \
    echo '        if adb connect $ADB_DEVICE_IP:$ADB_DEVICE_PORT; then' >> /app/connect-device.sh && \
    echo '            echo "Successfully connected to device"' >> /app/connect-device.sh && \
    echo '            break' >> /app/connect-device.sh && \
    echo '        fi' >> /app/connect-device.sh && \
    echo '        echo "Connection attempt failed"' >> /app/connect-device.sh && \
    echo '        sleep 2' >> /app/connect-device.sh && \
    echo '    done' >> /app/connect-device.sh && \
    echo 'fi' >> /app/connect-device.sh && \
    chmod +x /app/connect-device.sh

# Start supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
