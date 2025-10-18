#!/bin/bash
# Real-time Bluetooth mesh monitoring script for token transfers

echo "=== Bluetooth Mesh Monitoring Started ==="
echo "=== Watching for token transfers, errors, and peer activity ==="
echo ""

adb logcat -c
adb logcat \
  -s BluetoothEcashService:* \
  -s BluetoothMeshService:* \
  -s BluetoothPacketBroadcaster:* \
  -s MessageHandler:* \
  -s PacketProcessor:* \
  -s PeerManager:* \
  -s EncryptionService:* \
  -s "Capacitor/Console:*" \
  | grep --line-buffered -E "send|Send|token|Token|ecash|Ecash|peer|Peer|error|Error|fail|Fail|broadcast|Broadcast|received|Received|claimed|Claimed"




