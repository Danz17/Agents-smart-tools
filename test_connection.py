#!/usr/bin/env python3
"""Quick test script to try different ports and connection methods"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"

# Try different ports
ports_to_try = [
    (8728, False),  # Standard API port
    (8729, True),   # SSL API port
    (8729, False),  # Sometimes SSL port without SSL
]

print(f"Testing connection to {HOST}...\n")

for port, use_ssl in ports_to_try:
    print(f"Trying port {port} (SSL: {use_ssl})...")
    try:
        connection = connect(
            HOST, 
            username=USERNAME, 
            password=PASSWORD, 
            port=port,
            use_ssl=use_ssl
        )
        
        # Test by getting identity
        resource = connection.get_resource('/system/identity')
        identity = resource.get()
        router_name = identity[0]['name'] if identity else 'Unknown'
        
        print(f"[SUCCESS] Connected on port {port}!")
        print(f"Router Name: {router_name}\n")
        
        connection.disconnect()
        break
        
    except Exception as e:
        error_msg = str(e)
        if "refused" in error_msg.lower():
            print(f"[FAILED] Connection refused - API service may not be enabled\n")
        elif "timeout" in error_msg.lower():
            print(f"[FAILED] Connection timeout - router may be unreachable\n")
        else:
            print(f"[FAILED] {error_msg[:100]}\n")
else:
    print("\n[INFO] Could not connect on any port.")
    print("\nPlease ensure:")
    print("1. RouterOS API service is enabled (IP > Services > api)")
    print("2. Router is reachable at 10.1.1.1")
    print("3. Firewall allows connections on port 8728 or 8729")


