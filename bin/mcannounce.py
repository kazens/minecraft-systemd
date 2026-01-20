#!/usr/bin/python3
# Copyright (C) 2026 Karl Hastings <karl@passkeysec.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

import socket
import time
import sys
import os

# Minecraft LAN discovery constants
MULTICAST_IP = "224.0.2.60"
MULTICAST_PORT = 4445
BROADCAST_INTERVAL = 3

def load_minecraft_properties(filename):
    """
    Parses a Java .properties file into a dictionary.
    Handles comments (#, !), empty lines, and key=value pairs.
    """
    props = {}
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith(('#', '!')):
                    continue
                # Split only on the first '=' to allow '=' in the value
                if '=' in line:
                    key, value = line.split('=', 1)
                    props[key.strip()] = value.strip()
        return props
    except FileNotFoundError:
        return None

def run_broadcaster():
    # Identify which instance this is based on the directory name set by systemd
    instance_name = os.path.basename(os.getcwd())

    properties = load_minecraft_properties('server.properties')

    if properties is None:
        print(f"[{instance_name}] Error: 'server.properties' not found in {os.getcwd()}")
        sys.exit(1)

    # STRICT REQUIREMENT: server-port must exist for the broadcast to be valid
    if 'server-port' not in properties:
        print(f"[{instance_name}] Critical Error: 'server-port' missing from properties.")
        sys.exit(1)

    server_port = properties['server-port']
    
    # MOTD Priority: 'motd' property first, fallback to 'level-name'
    motd = properties.get('motd') or properties.get('level-name')

    if not motd:
        print(f"[{instance_name}] Critical Error: Neither 'motd' nor 'level-name' found in properties.")
        sys.exit(1)

    # Format required by the Minecraft client
    msg = f"[MOTD]{motd}[/MOTD][AD]{server_port}[/AD]".encode('utf-8')

    print(f"[{instance_name}] Starting broadcast: Port {server_port} | MOTD: {motd}")

    # Use a context manager to ensure the socket is closed on exit/crash
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        # Set Multicast Time-To-Live (2 is standard for small LANs)
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)

        try:
            while True:
                try:
                    sock.sendto(msg, (MULTICAST_IP, MULTICAST_PORT))
                except OSError as e:
                    print(f"[{instance_name}] Network error: {e}. Retrying in 15s...")
                    time.sleep(15)
                    continue

                time.sleep(BROADCAST_INTERVAL)
        except KeyboardInterrupt:
            print(f"\n[{instance_name}] Shutting down broadcaster...")

if __name__ == "__main__":
    run_broadcaster()
