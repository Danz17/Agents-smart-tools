#!/usr/bin/env python3
"""Check which ports are open on the router"""

import socket
import sys

HOST = "10.1.1.1"
PORTS_TO_CHECK = [22, 80, 443, 8728, 8729, 8080, 8291]  # Common MikroTik ports

def check_port(host, port, timeout=2):
    """Check if a port is open"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

print(f"Checking open ports on {HOST}...\n")

open_ports = []
for port in PORTS_TO_CHECK:
    print(f"Checking port {port}...", end=" ")
    if check_port(HOST, port):
        print("[OPEN]")
        open_ports.append(port)
    else:
        print("[CLOSED/FILTERED]")

print(f"\nOpen ports found: {open_ports}")

if 8728 in open_ports or 8729 in open_ports:
    print("\n[INFO] RouterOS API port is open! Try connecting again.")
elif open_ports:
    print(f"\n[INFO] Found open ports: {open_ports}")
    print("RouterOS API (8728/8729) is not accessible.")
    print("You may need to enable it or configure firewall rules.")
else:
    print("\n[WARNING] No common ports are open. Router may be unreachable or heavily firewalled.")


