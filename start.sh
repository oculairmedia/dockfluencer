#!/bin/bash
set -o pipefail
exec > >(tee -a "/app/logs/start_script.log") 2>&1

# Trap for unexpected exits
trap 'echo "Error on line $LINENO. Exit code: $?" >> /app/logs/start_script.log' ERR

echo "Starting script at $(date)"

cd /app
echo "Current directory: $(pwd)"

# Set up network for ADB
if [ -f "/app/setup-network.sh" ]; then
    echo "Running setup-network.sh"
    /app/setup-network.sh || echo "WARNING: Failed to set up network for ADB"
else
    echo "WARNING: setup-network.sh not found. Skipping network setup."
fi

export PYTHONPATH=/app
echo "PYTHONPATH set to $PYTHONPATH"

# Function to start ADB server
start_adb_server() {
    echo "Starting ADB server"
    adb -P 5037 start-server
    sleep 2
    if ! adb devices > /dev/null; then
        echo "WARNING: ADB server failed to start"
        return 1
    else
        echo "ADB server started successfully"
        return 0
    fi
}

# Function to connect to ADB device
connect_adb_device() {
    if [ -z "$ADB_DEVICE_IP" ] || [ -z "$ADB_DEVICE_PORT" ]; then
        echo "ERROR: ADB_DEVICE_IP or ADB_DEVICE_PORT not set"
        return 1
    fi

    echo "Connecting to device at $ADB_DEVICE_IP:$ADB_DEVICE_PORT"
    connection_success=false
    for i in {1..5}; do
        echo "Attempt $i/5: Connecting to device..."
        
        adb connect $ADB_DEVICE_IP:$ADB_DEVICE_PORT
        sleep 2
        
        if adb devices | grep -q "$ADB_DEVICE_IP:$ADB_DEVICE_PORT"; then
            if adb devices | grep "$ADB_DEVICE_IP:$ADB_DEVICE_PORT" | grep -q "unauthorized"; then
                echo "Device is unauthorized. Please check the device screen and accept the authorization prompt"
                echo "Waiting for authorization..."
                for j in {1..30}; do
                    if adb devices | grep "$ADB_DEVICE_IP:$ADB_DEVICE_PORT" | grep -q "device"; then
                        echo "Device successfully authorized!"
                        connection_success=true
                        break 2
                    fi
                    sleep 2
                done
                echo "Authorization timeout. Please manually authorize the device"
            elif adb devices | grep "$ADB_DEVICE_IP:$ADB_DEVICE_PORT" | grep -q "device"; then
                echo "Device successfully connected and authorized!"
                connection_success=true
                break
            fi
        fi
        
        echo "Connection attempt failed"
        adb disconnect $ADB_DEVICE_IP:$ADB_DEVICE_PORT
        sleep 2
    done

    if [ "$connection_success" = false ]; then
        echo "WARNING: Failed to connect to the device after 5 attempts"
        return 1
    fi
    return 0
}

# Kill any existing ADB server and processes
echo "Killing existing ADB server and processes"
adb kill-server
killall adb 2>/dev/null || true

# Start ADB server
start_adb_server || echo "WARNING: Failed to start ADB server, but continuing..."

# Ensure device authorization and generate new keys
echo "Generating new ADB keys"
mkdir -p /root/.android
rm -f /root/.android/adbkey /root/.android/adbkey.pub
if adb keygen /root/.android/adbkey; then
    echo "New ADB keys generated successfully"
    # Set proper permissions
    chmod 600 /root/.android/adbkey
    chmod 600 /root/.android/adbkey.pub
    echo "Permissions set for ADB keys"
else
    echo "ERROR: Failed to generate ADB keys"
    exit 1
fi

# Verify key generation
if [ ! -s "/root/.android/adbkey" ]; then
    echo "ERROR: ADB key file is empty or not generated"
    exit 1
fi

# Display ADB key information for debugging
echo "ADB key information:"
ls -l /root/.android/adbkey*
file /root/.android/adbkey

# Restart ADB server with new keys
echo "Restarting ADB server with new keys"
adb kill-server
start_adb_server || echo "WARNING: Failed to restart ADB server, but continuing..."

# Initial connection attempt
connect_adb_device || echo "WARNING: Initial connection attempt failed, but continuing..."

echo "ADB setup completed"

# Keep the container running
echo "Entering infinite loop to keep container running"
while true; do
    sleep 60
    echo "Container is still running at $(date)"
    # Periodic ADB connection check
    if ! adb devices | grep -q "$ADB_DEVICE_IP:$ADB_DEVICE_PORT"; then
        echo "WARNING: Device connection lost. Attempting to reconnect..."
        connect_adb_device || echo "WARNING: Reconnection attempt failed"
    fi
done
