#!/usr/bin/env python3
import sys
import serial
import time

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <serial_port> <binary_file>")
    sys.exit(1)

serial_port = sys.argv[1]
file_path = sys.argv[2]

ser = serial.Serial(
    port=serial_port,
    baudrate=9600,
    timeout=1
)

with open(file_path, 'rb') as f:
    data = f.read()

print(f"Sending {len(data)} bytes to {serial_port} at 9600 baud...")
for byte in data:
    ser.write(bytes([byte]))

ser.close()
print("Done.")

