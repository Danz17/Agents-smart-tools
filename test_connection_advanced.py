#!/usr/bin/env python3
"""Advanced connection test with different options"""

from routeros_api import connect

HOST = "10.1.1.1"
USERNAME = "admin"
PASSWORD = "admin123"

# Try different connection configurations
configs = [
    {"port": 8728, "use_ssl": False, "plaintext_login": False, "name": "Standard API"},
    {"port": 8728, "use_ssl": False, "plaintext_login": True, "name": "Standard API (plaintext)"},
    {"port": 8729, "use_ssl": True, "plaintext_login": False, "name": "SSL API"},
    {"port": 8729, "use_ssl": False, "plaintext_login": False, "name": "Port 8729 (no SSL)"},
    {"port": 80, "use_ssl": False, "plaintext_login": False, "name": "HTTP port"},
    {"port": 443, "use_ssl": True, "plaintext_login": False, "name": "HTTPS port"},
    {"port": 22, "use_ssl": False, "plaintext_login": False, "name": "SSH port"},
]

print(f"Testing various connection methods to {HOST}...\n")

for config in configs:
    name = config.pop("name")
    port = config["port"]
    print(f"Trying {name} (port {port})...")
    try:
        connection = connect(HOST, username=USERNAME, password=PASSWORD, **config)
        
        # Test by getting identity
        resource = connection.get_resource('/system/identity')
        identity = resource.get()
        router_name = identity[0]['name'] if identity else 'Unknown'
        
        print(f"[SUCCESS] Connected using {name} on port {port}!")
        print(f"Router Name: {router_name}\n")
        
        # Get more info
        resource = connection.get_resource('/system/resource')
        resources = resource.get()
        if resources:
            print(f"RouterOS Version: {resources[0].get('version', 'N/A')}")
            print(f"Uptime: {resources[0].get('uptime', 'N/A')}\n")
        
        connection.disconnect()
        print("Connection successful! You can now use routeros_connect.py or routeros_examples.py")
        exit(0)
        
    except Exception as e:
        error_msg = str(e)
        if "refused" in error_msg.lower():
            print(f"[FAILED] Connection refused\n")
        elif "timeout" in error_msg.lower():
            print(f"[FAILED] Connection timeout\n")
        elif "authentication" in error_msg.lower() or "login" in error_msg.lower():
            print(f"[FAILED] Authentication failed - wrong credentials?\n")
        else:
            print(f"[FAILED] {error_msg[:100]}\n")

print("\n[INFO] Could not establish connection with any tested configuration.")
print("\nThe RouterOS API service may need to be enabled on the router.")
print("You can enable it via:")
print("  - Winbox: IP > Services > api (enable and set port)")
print("  - WebFig: IP > Services > api")
print("  - CLI: /ip service enable api")


