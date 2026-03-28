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
# Safe UDP datagram size for typical LAN MTU (MOTD is truncated to fit).
MAX_UDP_PAYLOAD = 1400

# Linux: first TCP/UDP port a non-root process may bind without capabilities.
_UNPRIV_PORT_START_PROC = "/proc/sys/net/ipv4/ip_unprivileged_port_start"
_DEFAULT_UNPRIV_PORT_START = 1024


def min_unprivileged_listen_port():
    """
    Lowest port the minecraft user can typically bind (matches sysctl on Linux).
    Falls back to 1024 if unknown (e.g. non-Linux).
    """
    try:
        with open(_UNPRIV_PORT_START_PROC, encoding="utf-8") as f:
            n = int(f.read().strip())
    except (OSError, ValueError):
        return _DEFAULT_UNPRIV_PORT_START
    # 0 = kernel allows binding low ports without privilege on some setups
    return 1 if n <= 0 else n


def truncate_motd_for_udp(motd, server_port, max_payload):
    """
    Return (motd_for_broadcast, encoded_message, truncated).
    Truncates motd UTF-8 so the full LAN ping frame fits in max_payload octets.
    """
    prefix = "[MOTD]"
    suffix = f"[/MOTD][AD]{server_port}[/AD]"
    overhead = len(prefix.encode("utf-8")) + len(suffix.encode("utf-8"))
    max_motd = max_payload - overhead
    if max_motd < 1:
        max_motd = 0

    raw = motd.encode("utf-8")
    truncated = False
    if len(raw) > max_motd:
        truncated = True
        raw = raw[:max_motd]
        while raw:
            try:
                motd = raw.decode("utf-8")
                break
            except UnicodeDecodeError:
                raw = raw[:-1]
        else:
            motd = ""

    msg = f"{prefix}{motd}{suffix}".encode("utf-8")
    return motd, msg, truncated


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

    raw_port = properties['server-port'].strip()
    if not raw_port.isdigit():
        print(f"[{instance_name}] Critical Error: 'server-port' must be a decimal integer, got {raw_port!r}.")
        sys.exit(1)
    server_port = int(raw_port)
    min_port = min_unprivileged_listen_port()
    if not (min_port <= server_port <= 65535):
        print(
            f"[{instance_name}] Critical Error: 'server-port' must be {min_port}-65535 "
            f"(unprivileged bind range on this host), got {server_port}."
        )
        sys.exit(1)

    # MOTD Priority: 'motd' property first, fallback to 'level-name'
    motd = properties.get('motd') or properties.get('level-name')

    if not motd:
        print(f"[{instance_name}] Critical Error: Neither 'motd' nor 'level-name' found in properties.")
        sys.exit(1)

    motd_out, msg, motd_truncated = truncate_motd_for_udp(motd, server_port, MAX_UDP_PAYLOAD)
    if motd_truncated:
        print(
            f"[{instance_name}] Warning: MOTD truncated for LAN broadcast "
            f"({len(msg)} / {MAX_UDP_PAYLOAD} byte frame).",
            file=sys.stderr,
        )

    print(f"[{instance_name}] Starting broadcast: Port {server_port} | MOTD: {motd_out}")

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
